//
//  Input.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import CoreGraphics
import IOKit
import AppKit

import Output

/// The central manager for user input in Vosh.
///
/// `Input` is responsible for intercepting, processing, and routing keyboard events.
/// It implements global keyboard shortcuts, the "modifier" key logic (e.g., CapsLock as a Vosh modifier),
/// Input Help mode, typing echo, and Numpad Commander. It coordinates `KeyboardHook` and `ModifierListener`.
@MainActor public final class Input {
    
    // MARK: - Public State
    
    /// The set of standard keys currently being held down.
    public private(set) var regularKeys = Set<InputKeyCode>()
    
    /// The set of modifier keys currently being held down.
    public private(set) var modifierKeys = Set<InputModifierKeyCode>()
    
    /// Returns the shared singleton instance of the Input manager.
    public static let shared = Input()
    
    /// Magic number used to identify events injected by Vosh itself.
    /// Represents 'VOSH' in ASCII (0x56305348).
    public static let voshEventUserData: Int64 = 0x56305348

    /// Configuration: Whether "Browse Mode" (Virtual Cursor) is currently active.
    public var browseModeEnabled: Bool {get {state.browseModeEnabled} set {state.browseModeEnabled = newValue}}
    
    /// Configuration: Whether "Input Help" mode is active (announces keys instead of performing actions).
    public var inputHelpModeEnabled: Bool {get {state.inputHelpModeEnabled} set {state.inputHelpModeEnabled = newValue}}
    
    /// Configuration: Whether "Braille Input" mode is active (using keyboard as a braille display input).
    public var brailleInputEnabled: Bool {get {state.brailleInputEnabled} set {state.brailleInputEnabled = newValue}}
    
    /// Configuration: Defines which keys function as the "Vosh" modifier (e.g. CapsLock, or Control+Option).
    public var voshModifiers: Set<InputModifierKeyCode> = [.capsLock]
    
    // MARK: - Preferences
    
    public var typingEcho: Int = 1
    public var announceShift: Bool = false
    public var announceCommand: Bool = false
    public var announceControl: Bool = false
    public var announceOption: Bool = false
    public var announceCapsLock: Bool = false
    public var announceTab: Bool = false
    public var deletionFeedback: Int = 1
    
    // MARK: - Private Properties
    
    /// Internal input processing state.
    private let state = State()
    
    /// Helpers
    private let keyboardHook: KeyboardHook
    private let modifierListener: ModifierListener
    
    /// Buffer used for Word Echo processing.
    private var typingBuffer: String = ""
    
    /// Helper task to debounce modifier announcements.
    private var modifierAnnouncementTask: Task<Void, Never>?

    /// Access to the Trackpad input handler.
    public var trackpad: InputTrackpad { InputTrackpad.shared }
    
    // MARK: - Initialization
    
    private init() {
        self.keyboardHook = KeyboardHook()
        self.modifierListener = ModifierListener()
        
        // Initialize State
        state.capsLockEnabled = modifierListener.getCapsLockState()
        
        // Start Processing Tasks
        Task { await handleCapsLockStream() }
        Task { await handleModifierStream() }
        
        // Start Keyboard Hook
        keyboardHook.start { [weak self] event in
             return self?.handleEventTap(event)
        }
        
        // Monitoring Active State
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
             Task { @MainActor in
                 self?.resetModifiers()
             }
        }
    }
    
    public func passNextKeyToSystem() {
        state.passNextKey = true
        Output.shared.announce("Pass next key")
    }
    
    public func resetModifiers() {
        state.capsLockPressed = false
        modifierKeys.removeAll()
        regularKeys.removeAll()
        state.shouldInterrupt = false
        state.passNextKey = false
    }

    // MARK: - Key Binding

    public func bindKey(browseMode: Bool = false, controlModifier: Bool = false, optionModifier: Bool = false, commandModifier: Bool = false, shiftModifier: Bool = false, key: InputKeyCode, description: String? = nil, action: @escaping () async -> Void) {
        let binding = KeyBinding(browseMode: browseMode, controlModifier: controlModifier, optionModifier: optionModifier, commandModifier: commandModifier, shiftModifier: shiftModifier, key: key)
        state.keyBindings[binding] = action
        if let desc = description {
            state.bindingDescriptions[binding] = desc
        }
    }
    
    // MARK: - Stream Handlers
    
    private func handleCapsLockStream() async {
        for await (timestamp, isDown) in modifierListener.capsLockStream {
            state.capsLockPressed = isDown
            
            // Normalize Mach Timestamp
            var timeBase = mach_timebase_info(numer: 0, denom: 0)
            mach_timebase_info(&timeBase)
            let normalizedTime = timestamp / UInt64(timeBase.denom) * UInt64(timeBase.numer)
            
            if state.lastCapsLockEvent + 250000000 > normalizedTime && isDown {
                // Double Tap Logic
                state.lastCapsLockEvent = 0
                state.capsLockEnabled.toggle()
                modifierListener.setCapsLockState(state.capsLockEnabled)
                
                // Post actual Caps Lock event
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x39, keyDown: state.capsLockEnabled)
                event?.post(tap: .cghidEventTap)
                // Need Up event maybe? state.capsLockEnabled determines lock, but key press is down/up.
                // Replicating original logic: just one event? Original code: `keyDown: state.capsLockEnabled`.
                // Actually CapsLock key events toggle the state.
                
                Output.shared.convey([OutputSemantic.capsLockStatusChanged(state.capsLockEnabled)])
                continue
            }
            // Sync LED/Internal State
            modifierListener.setCapsLockState(state.capsLockEnabled)
            if isDown {
                state.lastCapsLockEvent = normalizedTime
            }
        }
    }
    
    private func handleModifierStream() async {
        for await event in modifierListener.modifierStream {
            if event.isDown {
                // Cancel previous announcement if we are chording modifiers (e.g. Ctrl... then Option)
                modifierAnnouncementTask?.cancel()
                
                state.shouldInterrupt = regularKeys.isEmpty && modifierKeys.isEmpty && (event.key == .leftControl || event.key == .rightControl)
                modifierKeys.insert(event.key)
                
                // DEBOUNCE: Schedule announcement
                modifierAnnouncementTask = Task {
                    // Wait 200ms. If user presses another key (like 'C' for Cmd+C), 
                    // handleEventTap -> processKeyDown will fire.
                    // We need to check if a regular key was pressed in the meantime.
                    try? await Task.sleep(nanoseconds: 200_000_000) 
                    
                    if Task.isCancelled { return }
                    if !self.regularKeys.isEmpty { return } // User typed a shortcut
                    
                    var shouldAnnounce = false
                    switch event.key {
                    case .leftShift, .rightShift: shouldAnnounce = announceShift
                    case .leftCommand, .rightCommand: shouldAnnounce = announceCommand
                    case .leftControl, .rightControl: shouldAnnounce = announceControl
                    case .leftOption, .rightOption: shouldAnnounce = announceOption
                    case .capsLock: shouldAnnounce = announceCapsLock
                    case .function: break
                    }
                    
                    if shouldAnnounce {
                        Output.shared.announce(event.key.description)
                    }
                }
                continue
            }
            
            modifierKeys.remove(event.key)
            if state.shouldInterrupt {
                Output.shared.interrupt()
                state.shouldInterrupt = false
            }
        }
    }
    
    // MARK: - Event Tap Processing
    
    private var swallowedKeys = Set<Int64>()
    
    private func handleEventTap(_ event: CGEvent) -> CGEvent? {
        // Ignore Vosh events
        if event.getIntegerValueField(.eventSourceUserData) == Input.voshEventUserData {
            return event
        }
        
        let kpCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // Pass Next Key Logic
        if state.passNextKey {
             if event.type == .keyDown {
                 let keyCode = Int(kpCode)
                 let isModifier = (54...62).contains(keyCode) // Rough range of modifiers
                 if !isModifier {
                    state.passNextKey = false
                 }
             }
             return event
        }
        
        // Safety: Stuck Caps Lock Check
        let isPhysicallyDown = CGEventSource.keyState(.combinedSessionState, key: 0x39)
        if state.capsLockPressed && !isPhysicallyDown {
            state.capsLockPressed = false
        }
        
        // Braille Input Processing (Pre-processing)
        if state.brailleInputEnabled && !state.capsLockPressed {
             let isDown = event.type == .keyDown
             Task { @MainActor in
                 BrailleInputManager.shared.process(keyCode: Int(kpCode), isDown: isDown)
             }
             return nil // Swallow event
        }
        
        if event.type == .keyDown {
            if processKeyDown(event) {
                swallowedKeys.insert(kpCode)
                return nil // Swallow
            }
        } else if event.type == .keyUp {
             let keyCode = kpCode
             
             // Handle release tracking
             if let inputKeyCode = InputKeyCode(rawValue: keyCode) {
                 regularKeys.remove(inputKeyCode)
             }
             
             // Swallow Orphaned KeyUp
             if swallowedKeys.contains(keyCode) {
                 swallowedKeys.remove(keyCode)
                 return nil
             }
        }
        
        // Typing Echo (Passthrough)
        if event.type == .keyDown && !state.capsLockPressed && !state.browseModeEnabled && !state.inputHelpModeEnabled {
            let keyCode = kpCode
            let chars = NSEvent(cgEvent: event)?.characters ?? ""
            Task { @MainActor in
                handleTypingEcho(chars: chars, keyCode: Int(keyCode))
            }
        }
        
        return event
    }
    
    /// Returns true if event should be swallowed.
    private func processKeyDown(_ event: CGEvent) -> Bool {
        // User pressed a real key, silence any pending modifier announcement
        modifierAnnouncementTask?.cancel()
        
        let keyCode = Int64(event.getIntegerValueField(.keyboardEventKeycode))
        guard let inputKeyCode = InputKeyCode(rawValue: keyCode) else { return false }
        
        state.shouldInterrupt = false
        regularKeys.insert(inputKeyCode)
        
        if state.inputHelpModeEnabled {
             Output.shared.announce("Key code \(keyCode)")
        }
        
        // Numpad Commander
        if state.numpadCommanderEnabled {
            let numpadCodes: Set<InputKeyCode> = [.keypad0, .keypad1AndEnd, .keypad2AndDownArrow, .keypad3AndPageDown, .keypad4AndLeftArrow, .keypad5, .keypad6AndRightArrow, .keypad7AndHome, .keypad8AndUpArrow, .keypad9AndPageUp, .keypadDecimalAndDelete, .keypadEquals, .keypadDivide, .keypadMultiply, .keypadSubtract, .keypadAdd, .keypadEnter]
            
            if numpadCodes.contains(inputKeyCode) {
                Task { [weak self] in
                    await self?.onNumpadCommand?(inputKeyCode)
                }
                if !state.inputHelpModeEnabled { return true }
            }
        }
        
        // Vosh Command Match
        let capsLockActive = state.capsLockPressed
        let ctrlOptionActive = modifierKeys.contains(.leftControl) && modifierKeys.contains(.leftOption)
        
        var isVoshActive = false
        if voshModifiers.contains(.capsLock) && capsLockActive { isVoshActive = true }
        if voshModifiers.contains(.leftControl) && voshModifiers.contains(.leftOption) && ctrlOptionActive { isVoshActive = true }
        
        let browseMode = state.browseModeEnabled && !isVoshActive
        let controlModifier = event.flags.contains(.maskControl)
        let optionModifier = event.flags.contains(.maskAlternate)
        let commandModifier = event.flags.contains(.maskCommand)
        let shiftModifier = event.flags.contains(.maskShift)
        
        let keyBinding = KeyBinding(browseMode: browseMode, controlModifier: controlModifier, optionModifier: optionModifier, commandModifier: commandModifier, shiftModifier: shiftModifier, key: inputKeyCode)
        
        // Input Help Mode Logic
        if state.inputHelpModeEnabled {
             var message = "\(inputKeyCode)"
             var mods = [String]()
             if isVoshActive { mods.append("Vosh") }
             else {
                 if controlModifier { mods.append("Ctrl") }
                 if optionModifier { mods.append("Opt") }
             }
             if shiftModifier { mods.append("Shift") }
             if commandModifier { mods.append("Cmd") }
             
             if !mods.isEmpty {
                 message = mods.joined(separator: "+") + " + \(inputKeyCode)"
             }
             
             if let desc = state.bindingDescriptions[keyBinding] {
                 message += ". Command: \(desc)"
                 // Exception: Toggle Input Help
                 if desc == "Toggle Input Help Mode" {
                     Task { await state.keyBindings[keyBinding]?() }
                     return true
                 }
             } else {
                 message += ". No command."
             }
             
             Output.shared.announce(message)
             return true
        }
        
        guard isVoshActive || state.browseModeEnabled else {
            return false
        }
        
        guard let action = state.keyBindings[keyBinding] else {
            return true // Swallow unbound Vosh keys? Or pass through?
            // If Vosh active (Caps Lock held), we should probably swallow to prevent system beeps or weird interactions.
            // If Browse Mode, we swallow navigation keys.
            // Return true to swallow.
        }
        
        Task { await action() }
        return true
    }

    private func handleTypingEcho(chars: String, keyCode: Int) {
        if keyCode == 51 { // Delete
            if deletionFeedback == 1 { Output.shared.announce("Delete") }
            else if deletionFeedback == 2 { SoundManager.shared.play(.delete) }
            if !typingBuffer.isEmpty { typingBuffer.removeLast() }
            return
        }
        
        guard !chars.isEmpty else { return }
        let char = chars.first!
        
        if (typingEcho == 1 || typingEcho == 3) {
             Output.shared.announce(chars)
        }
        
        if (typingEcho == 2 || typingEcho == 3) {
            if char.isWhitespace || char.isPunctuation || char.isNewline {
                if !typingBuffer.isEmpty {
                    Output.shared.announce(typingBuffer)
                    typingBuffer = ""
                }
            } else {
                typingBuffer.append(chars)
            }
        }
    }
    
    // MARK: - Numpad Commander Support
    
    public var onNumpadCommand: ((InputKeyCode) async -> Void)?
    
    public func setNumpadCommanderEnabled(_ enabled: Bool) {
        state.numpadCommanderEnabled = enabled
    }

    // MARK: - Internal Types
    
    private final class State {
        var browseModeEnabled = false
        var inputHelpModeEnabled = false
        var brailleInputEnabled = false
        var passNextKey = false
        var lastCapsLockEvent = UInt64(0)
        var capsLockEnabled = false
        var capsLockPressed = false
        var keyBindings = [KeyBinding: () async -> Void]()
        var bindingDescriptions = [KeyBinding: String]()
        var shouldInterrupt = false
        var numpadCommanderEnabled = false
    }

    private struct KeyBinding: Hashable {
        let browseMode: Bool
        let controlModifier: Bool
        let optionModifier: Bool
        let commandModifier: Bool
        let shiftModifier: Bool
        let key: InputKeyCode
    }
}
