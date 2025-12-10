//
//  Output.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AVFoundation
import ApplicationServices

/// The central manager for Accessible Output (Speech, Haptics, Audio).
///
/// `Output` coordinates the synthesized speech (`AVSpeechSynthesizer`), spatial audio feedback (`AudioEngine`),
/// haptic feedback, and on-screen visual overlays (`VoshHUD`). It also handles output customization options like
/// verbosity settings, pronunciation corrections, and punctuation modes.
@MainActor public final class Output: NSObject {
    
    /// Shared singleton instance.
    public static let shared = Output()

    /// The primary speech synthesizer engine.
    private let synthesizer = AVSpeechSynthesizer()
    
    /// Queue of semantic items waiting to be processed/spoken if an announcement is currently in progress (and not interrupted).
    /// Note: `Output` generally interrupts immediately by default for new user actions, but sequential reading uses this.
    private var queued = [OutputSemantic]()
    
    /// Flag indicating if the system is currently speaking an announcement.
    private var isAnnouncing = false
    
    // MARK: - Speech Configuration
    
    /// Speaking rate (0.0 to 1.0). Default is roughly 0.5.
    public var rate: Float = 0.5
    
    /// Speaking volume (0.0 to 1.0).
    public var volume: Float = 1.0
    
    /// Speaking pitch multiplier (0.5 to 2.0).
    public var pitch: Float = 1.0
    
    /// Identifier of the preferred voice (e.g., "com.apple.voice.compact.en-US.Samantha").
    public var selectedVoiceIdentifier: String?
    
    // MARK: - Verbosity & Formatting
    
    /// Verbosity Level (0: Low, 1: Medium, 2: High).
    public var verbosityLevel: Int = 1
    
    /// The order in which element attributes are spoken (e.g., ["name", "role", "status"]).
    public var verbosityOrder: [String] = ["name", "role", "status"]
    
    /// Punctuation verbosity mode (0: None, 1: Some, 2: All).
    public var punctuationMode: Int = 1
    
    /// Pitch change modifier for capital letters (not yet fully implemented in `applyConfig`).
    public var capsPitchChange: Float = 0.0
    
    /// Whether to say "Cap" before capitalized words/letters.
    public var speakCap: Bool = false
    
    /// Number reading style (0: Words/Auto, 1: Digits).
    public var numberStyle: Int = 0 
    
    // MARK: - Feedback Settings
    
    /// Feedback style for indentation changes (0: None, 1: Speak, 2: Tone).
    public var indentationFeedback: Int = 1
    
    /// Feedback style for repeated spaces (0: None, 1: Speak, 2: Tone).
    public var repeatedSpacesFeedback: Int = 0
    
    /// Feedback style for text attribute changes (0: None, 1: Speak, 2: Tone).
    public var textAttributesFeedback: Int = 1
    
    /// Feedback style for misspellings (0: None, 1: Speak, 2: Tone).
    public var misspellingFeedback: Int = 1
    
    /// Callback block for observing speech output (e.g., for the Speech History / Viewer).
    public var onSpeech: ((String) -> Void)?
    
    // MARK: - State
    
    /// Dictionary of custom text replacements (Original -> Replacement).
    public var pronunciations: [String: String] = [:]
    
    /// Global mute switch (Privacy Curtain). If true, speech output is suppressed.
    public var isMuted: Bool = false {
        didSet {
             if isMuted {
                 interrupt()
             }
        }
    }
    
    /// Manages the Screen Curtain (blackout) feature.
    private let screenCurtain = ScreenCurtain()
    
    /// Whether the Screen Curtain is currently active (screen is blacked out).
    public var isScreenCurtainEnabled: Bool {
        get { screenCurtain.isEnabled }
        set { screenCurtain.isEnabled = newValue }
    }
    
    // MARK: - Private state
    
    /// Current spatial audio X-position (pan) for the next utterance (0.0 left .. 1.0 right).
    private var currentSpatialPosition: CGFloat?

    /// Private initializer.
    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Spatial Audio Control
    
    /// Sets the spatial audio panning position for the *next* announcement.
    /// - Parameter x: Normalized X position (0.0 = Left, 0.5 = Center, 1.0 = Right).
    public func setSpatialPosition(_ x: CGFloat) {
        self.currentSpatialPosition = x
    }
    
    // MARK: - Public Methods
    
    /// Immediately announces a high-priority string.
    ///
    /// This bypasses the semantic queue and speaks the text immediately, interrupting current speech.
    /// It applies configured pronunciations and spatial audio positioning.
    ///
    /// - Parameters:
    ///   - announcement: The raw text string to speak.
    ///   - x: Optional spatial position override. If nil, uses `setSpatialPosition` value or center.
    public func announce(_ announcement: String, at x: CGFloat? = nil) {
        // Show visual HUD
        VoshHUD.shared.show(announcement)
        SpeechLogger.shared.log(announcement)
        
        guard !isMuted else { return }
        
        let position = x ?? currentSpatialPosition ?? 0.5
        
        if AudioEngine.shared.isSpatialEnabled {
             // Spatial Path
             speakSpatial(applyPronunciations(announcement), at: position)
        } else {
             // Standard Path
             let utterance = AVSpeechUtterance(string: applyPronunciations(announcement))
             applyConfig(to: utterance)
             synthesizer.stopSpeaking(at: .immediate)
             isAnnouncing = true
             synthesizer.speak(utterance)
        }
    }
    
    /// Converts a list of semantic output items into speech and feedback.
    ///
    /// This is the primary method for announcing UI state changes. It filters/orders
    /// items based on verbosity settings, plays appropriate earcons (sounds), triggers haptics,
    /// and speaks the text content.
    ///
    /// - Parameter content: An array of `OutputSemantic` items describing the event.
    public func convey(_ content: [OutputSemantic]) {
        guard !isMuted else { return }
        if isAnnouncing {
            queued = content
            return
        }
        queued = []
        synthesizer.stopSpeaking(at: .immediate)
        
        let processedContent = processVerbosity(content)
        
        for expression in processedContent {
            switch expression {
            case .apiDisabled: speak("Accessibility interface disabled")
            case let .application(label): speak(label); HapticManager.shared.play(.generic)
            case let .boolValue(bool): speak(bool ? "On" : "Off")
            case .boundary: SoundManager.shared.play(.boundary); HapticManager.shared.play(.alignment); continue
            case let .capsLockStatusChanged(status):
                SoundManager.shared.play(.click)
                speak("CapsLock \(status ? "On" : "Off")")
            case let .columnCount(count): speak("\(count) columns")
            case .disabled: speak("Disabled")
            case .edited: speak("Edited")
            case .entering: speak("Entering"); HapticManager.shared.play(.levelChange)
            case .exiting: speak("Exiting"); HapticManager.shared.play(.levelChange)
            case let .floatValue(val): speak(String(format: "%.02f", val))
            case let .help(txt): speak(txt)
            case let .insertedText(txt): speak(txt)
            case let .intValue(val): speak("\(val)")
            case let .label(lbl): speak(lbl)
            case .next, .previous: continue
            case .noFocus: speak("Nothing in focus")
            case .expanded: speak("expanded")
            case .collapsed: speak("collapsed")
            case .notAccessible: speak("Application not accessible")
            case let .placeholderValue(val): speak(val)
            case let .removedText(txt): SoundManager.shared.play(.delete); speak(txt)
            case let .role(r): speak(r)
            case let .rowCount(c): speak("\(c) rows")
            case .selected: speak("Selected"); HapticManager.shared.play(.generic)
            case let .selectedChildrenCount(c): speak("\(c) selected")
            case let .selectedText(t): speak(t)
            case let .selectedTextGrew(t): speak(t)
            case let .selectedTextShrank(t): speak(t)
            case let .stringValue(s): speak(s)
            case .timeout: speak("Application is not responding")
            case let .updatedLabel(l): speak(l)
            case let .urlValue(u): speak(u)
            case let .window(w): speak(w)
            
            // Phase 3 Handling
            case let .indentation(count):
                if indentationFeedback == 1 { speak("\(count) spaces indent") }
                else if indentationFeedback == 2 { SoundManager.shared.play(.texture) } // Tone
            case let .repeatedSpaces(count):
                 if repeatedSpacesFeedback == 1 { speak("\(count) spaces") }
                 else if repeatedSpacesFeedback == 2 { SoundManager.shared.play(.texture) }
            case .misspelling:
                 if misspellingFeedback == 1 { speak("Misspelled") }
                 else if misspellingFeedback == 2 { SoundManager.shared.play(.delete) } // Tone
            case .textAttributesChanged:
                 if textAttributesFeedback == 1 { speak("Attributes changed") }
                 else if textAttributesFeedback == 2 { SoundManager.shared.play(.levelChange) }
            }
        }
    }
    
    /// Stops all current speech and audio feedback immediately.
    public func interrupt() {
        isAnnouncing = false
        queued = []
        synthesizer.stopSpeaking(at: .immediate)
        AudioEngine.shared.stopSpeech()
    }
    
    // MARK: - Private Helpers
    
    /// Internal method to trigger spatial speech via `AudioEngine`.
    private func speakSpatial(_ string: String, at x: CGFloat) {
         // Stop previous
         AudioEngine.shared.stopSpeech() 
         isAnnouncing = true
         
         let utterance = AVSpeechUtterance(string: string)
         applyConfig(to: utterance)
         
         synthesizer.write(utterance) { buffer in
             guard let buffer = buffer as? AVAudioPCMBuffer else { return }
             AudioEngine.shared.play(buffer, at: x)
         }
    }
    
    /// Applies rate, pitch, volume, and voice settings to an `AVSpeechUtterance`.
    private func applyConfig(to utterance: AVSpeechUtterance) {
        utterance.rate = rate
        utterance.volume = volume
        utterance.pitchMultiplier = pitch
        if let id = selectedVoiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        }
    }

    /// Reorders and filters semantic content based on the user's `verbosityOrder` and `verbosityLevel`.
    private func processVerbosity(_ content: [OutputSemantic]) -> [OutputSemantic] {
        // Group content
        var names = [OutputSemantic]()
        var roles = [OutputSemantic]()
        var statuses = [OutputSemantic]()
        var others = [OutputSemantic]()
        
        for item in content {
            switch item {
            case .label, .stringValue, .intValue, .floatValue, .window, .application:
                names.append(item)
            case .role:
                roles.append(item)
            case .selected, .boolValue, .edited, .disabled, .expanded, .collapsed:
                statuses.append(item)
            default:
                others.append(item)
            }
        }
        
        // Filter based on Verbosity Level (Low = 0, Med = 1, High = 2)
        if verbosityLevel == 0 {
            // Low: Simplified output logic could go here.
        }
        
        // Reorder
        var ordered = [OutputSemantic]()
        // Always announce boundaries/context changes first (entering/exiting)
        ordered.append(contentsOf: others.filter { 
            if case .boundary = $0 { return true }
            if case .entering = $0 { return true }
            if case .exiting = $0 { return true }
            return false
        })
        
        for section in verbosityOrder {
            switch section {
            case "name": ordered.append(contentsOf: names)
            case "role": ordered.append(contentsOf: roles)
            case "status": ordered.append(contentsOf: statuses)
            default: break
            }
        }
        
        // Append remaining others (help, values, etc)
        ordered.append(contentsOf: others.filter {
            if case .boundary = $0 { return false }
            if case .entering = $0 { return false }
            if case .exiting = $0 { return false }
            return true
        })

        return ordered
    }
    
    /// Replaces strings based on current pronunciation dictionary.
    private func applyPronunciations(_ text: String) -> String {
        var processed = text
        for (original, replacement) in pronunciations {
            processed = processed.replacingOccurrences(of: original, with: replacement, options: [.caseInsensitive, .literal])
        }
        return processed
    }

    /// The most recent string announced by Vosh.
    public private(set) var lastSpoken: String?

    /// Internal speech primitive. Handles pre-processing like pronunciations, number style, and "Cap" prefixes.
    private func speak(_ string: String) {
        var text = applyPronunciations(string)
        
        // Update History
        lastSpoken = text
        
        // Number Style
        if numberStyle == 1 { // Digits
            // Simple regex replacement to space out digits for distinct enunciation
             text = text.replacingOccurrences(of: "(\\d)", with: "$1 ", options: .regularExpression)
        }
        
        // "Cap" announcement
        if speakCap {
             // Prepend "Cap" to capital letters
             text = text.replacingOccurrences(of: "([A-Z])", with: " Cap $1", options: .regularExpression)
        }
        
        // Notify listener
        let finalText = text
        Task { @MainActor in 
            onSpeech?(finalText)
            BrailleService.shared.output(finalText)
        }
        
        if AudioEngine.shared.isSpatialEnabled {
            speakSpatial(text, at: currentSpatialPosition ?? 0.5)
        } else {
            let utterance = AVSpeechUtterance(string: text)
            applyConfig(to: utterance)
            
            isAnnouncing = true
            synthesizer.speak(utterance)
        }
    }
}

extension Output: AVSpeechSynthesizerDelegate {
    /// Delegate method called when the synthesizer finishes speaking.
    /// Used to process the next queued item (for sequential reading).
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if isAnnouncing {
                isAnnouncing = false
                convey(queued)
            }
        }
    }
}
