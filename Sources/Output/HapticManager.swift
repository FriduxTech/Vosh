//
//  HapticManager.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// Manages haptic feedback via the system's Force Touch Trackpad.
///
/// `HapticManager` provides a high-level interface to the `NSHapticFeedbackManager`,
/// allowing Vosh to convey physical cues for events such as UI alignment, level changes,
/// and generic interactions.
@MainActor public final class HapticManager {
    
    /// Shared singleton instance.
    public static let shared = HapticManager()
    
    /// Helper property to enable or disable all haptic feedback globally.
    public var isEnabled = false
    
    /// Controls the intensity (placeholder for future custom haptic engines; standard API is fixed).
    public var intensity: Float = 1.0
    
    /// The system haptic feedback performer.
    private let performer = NSHapticFeedbackManager.defaultPerformer
    
    /// Private initializer.
    private init() {}
    
    /// Available haptic patterns.
    public enum Pattern {
        /// Generic click feeling.
        case generic
        /// Snapping feeling (stronger).
        case alignment
        /// Discrete step feeling (lighter).
        case levelChange
    }
    
    /// Triggers a haptic feedback pattern.
    ///
    /// - Parameter pattern: The type of feedback to perform.
    public func play(_ pattern: Pattern) {
        guard isEnabled else { return }
        
        let feedbackPattern: NSHapticFeedbackManager.FeedbackPattern
        switch pattern {
        case .generic: feedbackPattern = .generic
        case .alignment: feedbackPattern = .alignment
        case .levelChange: feedbackPattern = .levelChange
        }
        
        performer.perform(feedbackPattern, performanceTime: .now)
    }
    
    /// Simulates a texture effect (e.g., for boundaries or granular controls).
    ///
    /// Currently implemented as a generic tap but intended for expansion to more complex custom waveforms.
    public func playTexture() {
        guard isEnabled else { return }
        play(.generic)
    }
}
