//
//  AudioEngine.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AVFoundation
import AppKit

/// Manages the 3D spatial audio environment processing.
///
/// `AudioEngine` wraps `AVAudioEngine` to provide a spatial sound field for accessibility feedback.
/// It uses an `AVAudioEnvironmentNode` to position sounds in 3D space relative to the user ("listener").
/// This allows Vosh to place interface sounds and speech at positions corresponding to their on-screen location,
/// increasing spatial awareness.
@MainActor public final class AudioEngine {
    
    /// Shared singleton instance.
    public static let shared = AudioEngine()
    
    // MARK: - Core Components
    
    /// The underlying CoreAudio engine.
    private let engine = AVAudioEngine()
    
    /// The environment node enabling 3D audio features (mixes spatial inputs).
    private let environment = AVAudioEnvironmentNode()
    
    /// Dedicated mixer for standard UI sound effects (2D).
    private let sfxMixer = AVAudioMixerNode()
    
    /// Dedicated player node for spatialized speech.
    private let speechPlayer = AVAudioPlayerNode()
    
    /// Reverb effect node for environmental presence.
    private let reverb = AVAudioUnitReverb()
    
    // MARK: - Configuration
    
    /// Helper flag to enable/disable spatial processing logic.
    public var isSpatialEnabled = false
    
    /// Stereo separation width factor (Currently triggers listener update).
    public var stereoWidth: Float = 1.0 {
        didSet { updateListener() }
    }
    
    /// Reverb preset (e.g., smallRoom, cathedral).
    public var reverbPreset: AVAudioUnitReverbPreset = .smallRoom {
        didSet { updateReverb() }
    }
    
    /// Private initializer setting up the audio graph.
    private init() {
        setupGraph()
        start()
    }
    
    /// Configures the AVAudioEngine graph connections.
    private func setupGraph() {
        // Attach nodes
        engine.attach(environment)
        engine.attach(sfxMixer)
        engine.attach(speechPlayer)
        engine.attach(reverb)
        
        // Connect Environment -> Reverb -> Main Mixer
        let format = engine.outputNode.inputFormat(forBus: 0)
        
        // 1. Sources -> Environment
        // We connect the sources to the environment node with specific formats
        // For 3D audio, we usually want Mono inputs panning in the Environment
        
        // 2. Connect Environment to Reverb
        engine.connect(environment, to: reverb, format: format)
        
        // 3. Connect Reverb to Main Output
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        
        // Listener Configuration (The User)
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environment.listenerAngularOrientation = AVAudioMake3DAngularOrientation(0, 0, 0) // Looking forward
        
        // Configure Reverb
        reverb.loadFactoryPreset(reverbPreset)
        reverb.wetDryMix = 20 // Subtle by default
        
        updateListener()
    }
    
    /// Starts the audio engine.
    private func start() {
        do {
            try engine.start()
            print("Vosh Audio Engine Started")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// Updates listener attributes based on configuration.
    private func updateListener() {
        // Adjust stereo separation logic if needed, usually managed by node positions
        // Potentially adjust environment.distanceAttenuationParameters here
    }
    
    /// Updates the reverb preset.
    private func updateReverb() {
        reverb.loadFactoryPreset(reverbPreset)
    }
    
    // MARK: - Playback
    
    // Simple pool of players to avoid creating/destroying nodes constantly.
    private var playerPool: [AVAudioPlayerNode] = []
    private var activePlayers: Set<AVAudioPlayerNode> = []
    private let poolSize = 10
    
    private func getPlayer(format: AVAudioFormat) -> AVAudioPlayerNode {
        // Recycle: Find player with matching format if possible?
        // Or just reconnect if format differs?
        // Connecting is the heavy part.
        // Assuming most speech uses same format.
        
        if let existing = playerPool.popLast() {
            activePlayers.insert(existing)
            return existing
        }
        
        let newPlayer = AVAudioPlayerNode()
        engine.attach(newPlayer)
        // Pre-connect to environment with the requested format
        engine.connect(newPlayer, to: environment, format: format)
        activePlayers.insert(newPlayer)
        return newPlayer
    }
    
    private func returnPlayer(_ player: AVAudioPlayerNode) {
        player.stop()
        activePlayers.remove(player)
        // Keep pool size manageable
        if playerPool.count < poolSize {
            playerPool.append(player)
        } else {
            engine.detach(player)
        }
    }

    /// Stops any currently playing speech audio.
    public func stopSpeech() {
        speechPlayer.stop()
        // Stop all ephemeral players too?
        for player in activePlayers {
            player.stop()
        }
    }

    /// Plays an audio buffer spatialized at a specific horizontal position.
    ///
    /// The position is mapped from screen coordinates (0.0 to 1.0) to audio environment coordinates
    /// (Left to Right), with the listener centered.
    ///
    /// - Parameters:
    ///   - buffer: The `AVAudioPCMBuffer` containing the audio data (typically speech).
    ///   - position: Normalized X position (0.0 = Left, 1.0 = Right).
    public func play(_ buffer: AVAudioPCMBuffer, at position: CGFloat) {
        guard isSpatialEnabled else {
            // Fallback logic for non-spatial mode could use 2D panning via sfxMixer
            return
        }
        
        let player = getPlayer(format: buffer.format)
        
        // Coordinate Mapping:
        // Listener at (0, 0, 0)
        // Screen Plane at Z = -5.0 (In front of listener)
        // Screen Width mapped to X = -10 (Left) to +10 (Right)
        
        let x = Float(position - 0.5) * 20.0 // -10 to 10
        let z = Float(-5.0)
        
        // Verify connection format matches buffer
        // Safety Check: If we reused a player, it might be connected with a different format.
        if let output = engine.outputConnectionPoints(for: player, outputBus: 0).first {
             // Check if the player's output format matches the buffer
             let currentFormat = player.outputFormat(forBus: 0)
             if output.node === environment && currentFormat != buffer.format {
                 // Format mismatch detected. Reconnect.
                 engine.disconnectNodeOutput(player)
                 // This connect call is "heavy" but necessary if format changed.
                 engine.connect(player, to: environment, format: buffer.format)
             }
        } else {
             // Not connected (shouldn't happen with getPlayer logic but safe to handle)
             engine.connect(player, to: environment, format: buffer.format)
        }
        
        player.position = AVAudio3DPoint(x: x, y: 0, z: z)
        player.reverbBlend = 0.5 // Allow some reverb
        
        player.scheduleBuffer(buffer, at: nil, options: []) {
            Task { @MainActor [weak self] in
                self?.returnPlayer(player)
            }
        }
        player.play()
    }
    
    /// Returns the main mixer's output format, useful for format matching.
    public var mainFormat: AVAudioFormat {
        return engine.mainMixerNode.outputFormat(forBus: 0)
    }
}
