//
//  Preferences.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import Output
import AVFoundation

/// Singleton managing persistent application settings via `UserDefaults`.
///
/// `Preferences` handles the storage, retrieval, and synchronization of all user configuration options,
/// from speech details (rate, volume) to navigation behaviors (cursor tracking, wrapping) and advanced input features.
@MainActor
public final class Preferences {
    
    /// Shared singleton instance.
    public static let shared = Preferences()
    
    /// Reference to standard user defaults.
    private let defaults = UserDefaults.standard
    
    // MARK: - Constants: Keys
    
    private let kSpeechRate = "speechRate"
    private let kSpeechVolume = "speechVolume"
    private let kSoundVolume = "soundVolume"
    private let kVerbosity = "verbosity"
    
    // MARK: - Speech Settings
    
    /// Speech rate multiplier (0.0 - 1.0).
    /// Defaults to 0.5. Updates `Output.shared.rate` immediately upon set.
    public var speechRate: Float {
        get { defaults.float(forKey: kSpeechRate) == 0 ? 0.5 : defaults.float(forKey: kSpeechRate) }
        set { 
            defaults.set(newValue, forKey: kSpeechRate) 
            Output.shared.rate = newValue
        }
    }
    
    /// Speech output volume (0.0 - 1.0).
    /// Defaults to 1.0. Updates `Output.shared.volume` immediately.
    public var speechVolume: Float {
        get { defaults.float(forKey: kSpeechVolume) == 0 ? 1.0 : defaults.float(forKey: kSpeechVolume) }
        set { 
            defaults.set(newValue, forKey: kSpeechVolume) 
            Output.shared.volume = newValue
        }
    }
    
    /// System sounds effect volume (0.0 - 1.0).
    /// Defaults to 0.8.
    public var soundVolume: Float {
        get { defaults.float(forKey: kSoundVolume) == 0 ? 0.8 : defaults.float(forKey: kSoundVolume) }
        set { defaults.set(newValue, forKey: kSoundVolume) }
    }
    
    // MARK: - Audio Settings
    
    /// Whether to lower other system audio while Vosh is speaking (Audio Ducking).
    public var audioDucking: Bool {
        get { defaults.bool(forKey: "audioDucking") }
        set { 
            defaults.set(newValue, forKey: "audioDucking")
            // Output.shared.updateDucking(newValue) // TODO: Implement ducking switch
        }
    }
    
    /// Controls 3D Spatial Audio processing.
    public var spatialAudioEnabled: Bool {
        get { defaults.bool(forKey: "spatialAudio") }
        set {
            defaults.set(newValue, forKey: "spatialAudio")
            AudioEngine.shared.isSpatialEnabled = newValue
        }
    }
    
    /// Stereo separation factor (0.0 = Mono, 1.0 = Regular, >1.0 = Wide).
    public var stereoWidth: Float {
        get { defaults.float(forKey: "stereoWidth") == 0 ? 1.0 : defaults.float(forKey: "stereoWidth") }
        set {
            defaults.set(newValue, forKey: "stereoWidth")
            AudioEngine.shared.stereoWidth = newValue
        }
    }
    
    /// Environmental Reverb Preset index.
    public var reverbPreset: Int {
        get { defaults.integer(forKey: "reverbPreset") }
        set {
            defaults.set(newValue, forKey: "reverbPreset")
            AudioEngine.shared.reverbPreset = mapReverbAndSet(newValue)
        }
    }
    
    /// Maps integer index to `AVAudioUnitReverbPreset`.
    private func mapReverbAndSet(_ value: Int) -> AVAudioUnitReverbPreset {
        switch value {
        case 0: return .smallRoom
        case 1: return .mediumRoom
        case 2: return .largeRoom
        case 3: return .cathedral
        default: return .smallRoom
        }
    }
    
    // MARK: - Enums
    
    /// Amount of detail in spoken announcements.
    public enum VerbosityLevel: Int {
        case low = 0
        case medium = 1
        case high = 2
    }
    
    /// Level of punctuation to pronounce.
    public enum PunctuationMode: Int {
        /// Speak no punctuation.
        case none = 0
        /// Speak critical punctuation only.
        case some = 1
        /// Speak most punctuation.
        case most = 2
        /// Speak all punctuation symbols.
        case all = 3
    }
    
    /// Style for reading numbers.
    public enum NumberReadingStyle: Int {
        /// "One Hundred and Twenty Three".
        case words = 0
        /// "One Two Three".
        case digits = 1
    }
    
    // MARK: - Verbosity & Formatting Properties
    
    /// Current verbosity level.
    public var verbosityLevel: VerbosityLevel {
        get { VerbosityLevel(rawValue: defaults.integer(forKey: "verbosityLevel")) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: "verbosityLevel") }
    }
    
    /// Ordered list of attributes to speak (e.g., ["name", "role", "status"]).
    public var verbosityOrder: [String] {
        get { defaults.stringArray(forKey: "verbosityOrder") ?? ["name", "role", "status"] }
        set { defaults.set(newValue, forKey: "verbosityOrder") }
    }
    
    /// Whether to announce the element's name/label.
    public var speakName: Bool {
        get { defaults.object(forKey: "speakName") == nil ? true : defaults.bool(forKey: "speakName") }
        set { defaults.set(newValue, forKey: "speakName") }
    }
    
    /// Whether to announce the element's role (e.g., "Button").
    public var speakRole: Bool {
        get { defaults.object(forKey: "speakRole") == nil ? true : defaults.bool(forKey: "speakRole") }
        set { defaults.set(newValue, forKey: "speakRole") }
    }
    
    /// Whether to announce the element's status/value (e.g., "Checked").
    public var speakStatus: Bool {
        get { defaults.object(forKey: "speakStatus") == nil ? true : defaults.bool(forKey: "speakStatus") }
        set { defaults.set(newValue, forKey: "speakStatus") }
    }
    
    /// Punctuation verbosity setting.
    public var punctuationMode: PunctuationMode {
        get { PunctuationMode(rawValue: defaults.integer(forKey: "punctuationMode")) ?? .some }
        set { defaults.set(newValue.rawValue, forKey: "punctuationMode") }
    }
    
    /// Max number of repeated punctuation characters to speak before summarizing.
    public var repeatedPunctuationLimit: Int {
        get { defaults.integer(forKey: "repeatedPunctuationLimit") == 0 ? 3 : defaults.integer(forKey: "repeatedPunctuationLimit") }
        set { defaults.set(newValue, forKey: "repeatedPunctuationLimit") }
    }
    
    /// Style used when reading numbers.
    public var numberStyle: NumberReadingStyle {
        get { NumberReadingStyle(rawValue: defaults.integer(forKey: "numberStyle")) ?? .words }
        set { defaults.set(newValue.rawValue, forKey: "numberStyle") }
    }
    
    /// Percentage pitch increase for capital letters.
    public var capPitchChange: Float {
        get { defaults.float(forKey: "capPitchChange") }
        set { defaults.set(newValue, forKey: "capPitchChange") }
    }
    
    /// Whether to explicitly announce "Cap" before capitalized words.
    public var speakCap: Bool {
        get { defaults.bool(forKey: "speakCap") }
        set { defaults.set(newValue, forKey: "speakCap") }
    }
    
    /// Whether to use phonetic alphabet (e.g. "Alpha", "Bravo") when reading characters.
    public var speakPhonetics: Bool {
        get { defaults.bool(forKey: "speakPhonetics") }
        set { defaults.set(newValue, forKey: "speakPhonetics") }
    }
    
    // MARK: - Typing & Keyboard Properties
    
    /// Typing echo behavior.
    public enum TypingEcho: Int {
        case none = 0
        case characters = 1
        case words = 2
        case both = 3
    }
    
    /// Feedback style for deletion (Backspace/Delete).
    public enum DeletionFeedback: Int {
        case none = 0
        case speak = 1
        case tone = 2
    }
    
    /// Current typing echo preference.
    public var typingEcho: TypingEcho {
        get { TypingEcho(rawValue: defaults.integer(forKey: "typingEcho")) ?? .characters }
        set { defaults.set(newValue.rawValue, forKey: "typingEcho") }
    }
    
    // MARK: Modifier Keys Announcements
    
    public var announceShift: Bool {
        get { defaults.bool(forKey: "announceShift") }
        set { defaults.set(newValue, forKey: "announceShift") }
    }
    
    public var announceCommand: Bool {
        get { defaults.bool(forKey: "announceCommand") }
        set { defaults.set(newValue, forKey: "announceCommand") }
    }
    
    public var announceControl: Bool {
        get { defaults.bool(forKey: "announceControl") }
        set { defaults.set(newValue, forKey: "announceControl") }
    }
    
    public var announceIndentation: Bool {
        get { defaults.bool(forKey: "announceIndentation") }
        set { defaults.set(newValue, forKey: "announceIndentation") }
    }
    
    // MARK: Focus & Navigation
    
    /// Whether Vosh should try to intelligently focus newly opened windows or alerts.
    public var intelligentAutoFocus: Bool {
        get { defaults.object(forKey: "intelligentAutoFocus") == nil ? true : defaults.bool(forKey: "intelligentAutoFocus") }
        set { defaults.set(newValue, forKey: "intelligentAutoFocus") }
    }
    
    public var announceOption: Bool {
        get { defaults.bool(forKey: "announceOption") }
        set { defaults.set(newValue, forKey: "announceOption") }
    }
    
    public var announceCapsLock: Bool {
        get { defaults.bool(forKey: "announceCapsLock") }
        set { defaults.set(newValue, forKey: "announceCapsLock") }
    }
    
    public var announceTab: Bool {
        get { defaults.bool(forKey: "announceTab") }
        set { defaults.set(newValue, forKey: "announceTab") }
    }
    
    /// Feedback style provided when deleting text.
    public var deletionFeedback: DeletionFeedback {
        get { DeletionFeedback(rawValue: defaults.integer(forKey: "deletionFeedback")) ?? .speak }
        set { defaults.set(newValue.rawValue, forKey: "deletionFeedback") }
    }
    
    // MARK: - Feedback Styles
    
    /// General feedback types (Speech, Sound, None).
    public enum FeedbackStyle: Int {
        case none = 0
        case speak = 1
        case tone = 2
    }
    
    public var indentationFeedback: FeedbackStyle {
        get { FeedbackStyle(rawValue: defaults.integer(forKey: "indentationFeedback")) ?? .speak }
        set { defaults.set(newValue.rawValue, forKey: "indentationFeedback") }
    }
    
    public var repeatedSpacesFeedback: FeedbackStyle {
        get { FeedbackStyle(rawValue: defaults.integer(forKey: "repeatedSpacesFeedback")) ?? .none }
        set { defaults.set(newValue.rawValue, forKey: "repeatedSpacesFeedback") }
    }
    
    public var textAttributesFeedback: FeedbackStyle {
        get { FeedbackStyle(rawValue: defaults.integer(forKey: "textAttributesFeedback")) ?? .speak }
        set { defaults.set(newValue.rawValue, forKey: "textAttributesFeedback") }
    }
    
    public var misspellingFeedback: FeedbackStyle {
        get { FeedbackStyle(rawValue: defaults.integer(forKey: "misspellingFeedback")) ?? .speak }
        set { defaults.set(newValue.rawValue, forKey: "misspellingFeedback") }
    }
    
    // MARK: - Events & Progress
    
    public var autoSpeakDialogs: Bool {
        get { defaults.bool(forKey: "autoSpeakDialogs") }
        set { defaults.set(newValue, forKey: "autoSpeakDialogs") }
    }
    
    public var progressFeedback: FeedbackStyle {
        get { FeedbackStyle(rawValue: defaults.integer(forKey: "progressFeedback")) ?? .tone }
        set { defaults.set(newValue.rawValue, forKey: "progressFeedback") }
    }
    
    public var speakBackgroundProgress: Bool {
        get { defaults.bool(forKey: "speakBackgroundProgress") }
        set { defaults.set(newValue, forKey: "speakBackgroundProgress") }
    }
    
    public var tableRowChangeFeedback: FeedbackStyle {
        get { FeedbackStyle(rawValue: defaults.integer(forKey: "tableRowChangeFeedback")) ?? .speak }
        set { defaults.set(newValue.rawValue, forKey: "tableRowChangeFeedback") }
    }
    
    // MARK: - Mouse Interaction
    
    public var speakTextUnderMouse: Bool {
        get { defaults.bool(forKey: "speakTextUnderMouse") }
        set { defaults.set(newValue, forKey: "speakTextUnderMouse") }
    }
    
    public var speakUnderMouseDelay: Double {
        get { defaults.double(forKey: "speakUnderMouseDelay") }
        set { defaults.set(newValue, forKey: "speakUnderMouseDelay") }
    }
    
    /// Use mouse storage for VoiceOver cursor tracking.
    public var mouseFollowsCursor: Bool {
        get { defaults.bool(forKey: "mouseFollowsCursor") }
        set { defaults.set(newValue, forKey: "mouseFollowsCursor") }
    }
    
    /// Use VoiceOver cursor to follow mouse.
    public var cursorFollowsMouse: Bool {
        get { defaults.bool(forKey: "cursorFollowsMouse") }
        set { defaults.set(newValue, forKey: "cursorFollowsMouse") }
    }
    
    /// Initial position of cursor in new windows (0=Focused item, 1=First item).
    public var cursorInitialPosition: Int {
        get { defaults.integer(forKey: "cursorInitialPosition") }
        set { defaults.set(newValue, forKey: "cursorInitialPosition") }
    }
    
    public var syncFocus: Bool {
        get { defaults.bool(forKey: "syncFocus") }
        set { defaults.set(newValue, forKey: "syncFocus") }
    }
    
    public var wrapAround: Bool {
        get { defaults.bool(forKey: "wrapAround") }
        set { defaults.set(newValue, forKey: "wrapAround") }
    }
    
    public var autoInteractOnTab: Bool {
        get { defaults.bool(forKey: "autoInteractOnTab") }
        set { defaults.set(newValue, forKey: "autoInteractOnTab") }
    }
    
    // MARK: - Web Navigation
    
    /// Enables Browse Mode (Virtual Cursor navigation) on web content.
    /// If false, behaves strictly like VoiceOver (System Focus only/Interaction).
    public var enableBrowseMode: Bool {
        get { defaults.object(forKey: "enableBrowseMode") == nil ? true : defaults.bool(forKey: "enableBrowseMode") }
        set { defaults.set(newValue, forKey: "enableBrowseMode") }
    }
    
    public enum WebLoadFeedback: Int {
        case none = 0
        case progress = 1
        case tone = 2
    }
    
    public var webLoadFeedback: WebLoadFeedback {
        get { WebLoadFeedback(rawValue: defaults.integer(forKey: "webLoadFeedback")) ?? .tone }
        set { defaults.set(newValue.rawValue, forKey: "webLoadFeedback") }
    }
    
    public var speakWebSummary: Bool {
        get { defaults.bool(forKey: "speakWebSummary") }
        set { defaults.set(newValue, forKey: "speakWebSummary") }
    }
    
    public var autoReadWebPage: Bool {
        get { defaults.bool(forKey: "autoReadWebPage") }
        set { defaults.set(newValue, forKey: "autoReadWebPage") }
    }
    
    // MARK: - General System
    
    public var startAtLogin: Bool {
        get { defaults.bool(forKey: "startAtLogin") }
        set { defaults.set(newValue, forKey: "startAtLogin") }
    }
    
    // MARK: - Advanced Speech
    
    /// Speech pitch multiplier.
    public var pitch: Float {
        get { defaults.float(forKey: "speechPitch") == 0 ? 1.0 : defaults.float(forKey: "speechPitch") }
        set { 
            defaults.set(newValue, forKey: "speechPitch") 
            Output.shared.pitch = newValue
        }
    }
    
    /// Identifier for the user's preferred TTS voice.
    public var selectedVoiceIdentifier: String? {
        get { defaults.string(forKey: "selectedVoiceIdentifier") }
        set {
             defaults.set(newValue, forKey: "selectedVoiceIdentifier")
             Output.shared.selectedVoiceIdentifier = newValue
        }
    }
    
    public var punctuationLevel: Int {
        get { defaults.integer(forKey: "punctuationLevel") }
        set { defaults.set(newValue, forKey: "punctuationLevel") }
    }
    
    // MARK: - Navigation Features
    
    public var mouseTracking: Bool {
        get { defaults.bool(forKey: "mouseTracking") }
        set { defaults.set(newValue, forKey: "mouseTracking") }
    }
    
    public var focusVisuals: Bool {
        get { defaults.bool(forKey: "focusVisuals") }
        set { defaults.set(newValue, forKey: "focusVisuals") }
    }
    
    // MARK: - Haptics
    
    public var hapticsEnabled: Bool {
        get { defaults.bool(forKey: "hapticsEnabled") }
        set {
            defaults.set(newValue, forKey: "hapticsEnabled")
            HapticManager.shared.isEnabled = newValue
        }
    }
    
    public var hapticIntensity: Float {
        get { defaults.float(forKey: "hapticIntensity") == 0 ? 1.0 : defaults.float(forKey: "hapticIntensity") }
        set {
            defaults.set(newValue, forKey: "hapticIntensity")
            HapticManager.shared.intensity = newValue
        }
    }
    
    // MARK: - Document / Layout
    
    /// Use document layout referencing instead of screen layout.
    public var documentLayout: Bool {
        get { defaults.bool(forKey: "documentLayout") }
        set { defaults.set(newValue, forKey: "documentLayout") }
    }
    
    // MARK: - Vision / Screen Curtain
    
    /// Enables Screen Curtain (blacking out the screen for privacy).
    public var screenCurtain: Bool {
        get { defaults.bool(forKey: "screenCurtain") }
        set { 
            defaults.set(newValue, forKey: "screenCurtain") 
            Output.shared.isScreenCurtainEnabled = newValue
        }
    }
    
    // MARK: - Braille
    
    public var brailleEnabled: Bool {
        get { defaults.bool(forKey: "brailleEnabled") }
        set { defaults.set(newValue, forKey: "brailleEnabled") }
    }
    
    public var brailleTranslationTable: String {
        get { defaults.string(forKey: "brailleTable") ?? "English Grade 1" }
        set { defaults.set(newValue, forKey: "brailleTable") }
    }
    
    public var brailleStatusCellValues: Bool {
        get { defaults.bool(forKey: "brailleStatus") }
        set { defaults.set(newValue, forKey: "brailleStatus") }
    }
    
    // MARK: - OCR
    
    public var ocrLanguage: String {
        get { defaults.string(forKey: "ocrLanguage") ?? "English" }
        set { defaults.set(newValue, forKey: "ocrLanguage") }
    }
    
    // MARK: - Keyboard Layout
    
    public var keyboardLayout: String {
        get { defaults.string(forKey: "kbLayout") ?? "Laptop" } // Laptop / Desktop
        set { defaults.set(newValue, forKey: "kbLayout") }
    }
    
    public var sleepMode: Bool {
        get { defaults.bool(forKey: "sleepMode") }
        set { defaults.set(newValue, forKey: "sleepMode") }
    }
    
    // MARK: - Custom Messages
    
    public var greetingMessage: String {
        get { defaults.string(forKey: "greetingMessage") ?? "VOSH is ready" }
        set { defaults.set(newValue, forKey: "greetingMessage") }
    }
    
    public var goodbyeMessage: String {
        get { defaults.string(forKey: "goodbyeMessage") ?? "Exiting VOSH" }
        set { defaults.set(newValue, forKey: "goodbyeMessage") }
    }
    
    public var confirmOnExit: Bool {
        get { defaults.bool(forKey: "confirmOnExit") }
        set { defaults.set(newValue, forKey: "confirmOnExit") }
    }
    
    // MARK: - Numpad Commander
    
    public var numpadCommanderEnabled: Bool {
        get { defaults.bool(forKey: "numpadCommanderEnabled") }
        set { defaults.set(newValue, forKey: "numpadCommanderEnabled") }
    }
    
    // MARK: - Vosh Modifiers
    
    /// Modifier keys active for Vosh commands.
    public struct VoshModifiers: OptionSet, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        
        public static let capsLock = VoshModifiers(rawValue: 1 << 0)
        public static let numpad0 = VoshModifiers(rawValue: 1 << 1)
        public static let ctrlOption = VoshModifiers(rawValue: 1 << 2) // VO Keys
    }
    
    public var voshModifiers: VoshModifiers {
        get {
            let val = defaults.integer(forKey: "voshModifiers")
            return val == 0 ? .capsLock : VoshModifiers(rawValue: val)
        }
        set { defaults.set(newValue.rawValue, forKey: "voshModifiers") }
    }
    
    // MARK: - Pronunciation Dictionary
    
    /// User-defined pronunciation replacements.
    public var pronunciations: [String: String] {
        get { defaults.dictionary(forKey: "pronunciations") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "pronunciations") }
    }
    
    // MARK: - Key Mappings
    
    /// Custom key binding definitions.
    public struct KeyShortcut: Codable, Equatable {
        public let keyCode: Int
        public let modifiers: Int // NSEvent.ModifierFlags.rawValue
        
        public init(keyCode: Int, modifiers: Int) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }
    }
    
    public var keyMapping: [String: KeyShortcut] {
        get {
            guard let data = defaults.data(forKey: "keyMapping"),
                  let mapping = try? JSONDecoder().decode([String: KeyShortcut].self, from: data) else {
                return [:]
            }
            return mapping
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "keyMapping")
            }
        }
    }
    
    // MARK: - Gesture Mappings
    
    /// Custom trackpad gesture mappings.
    public var gestureMapping: [String: String] {
        get { defaults.dictionary(forKey: "gestureMapping") as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: "gestureMapping") }
    }
    
    /// Internal initializer registering default values.
    private init() {
        defaults.register(defaults: [
            kSpeechRate: 0.5,
            kSpeechVolume: 1.0,
            kSoundVolume: 0.8,
            "verbosityLevel": 1,
            "punctuationMode": 1,
            "capPitchChange": 20.0,
            "typingEcho": 1, 
            "deletionFeedback": 1,
            "indentationFeedback": 1,
            "autoSpeakDialogs": false,
            "syncFocus": true,
            "wrapAround": true,
            "audioDucking": false,
            "webLoadFeedback": 2
        ])
        
        // Apply immediate settings to output
        Output.shared.rate = speechRate
        Output.shared.volume = speechVolume
    }
}
