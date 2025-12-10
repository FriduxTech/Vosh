//
//  BrailleInputManager.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import Carbon
import Output

/// Manages Braille Screen Input via standard keyboard simulation.
///
/// This class enables "Perkins-style" 6-dot braille input using the keyboard home row (S-D-F-J-K-L).
/// It aggregates concurrent key presses into chords, translates them into characters using basic
/// Grade 1 Braille logic, and reinjects the resulting text into the system.
@MainActor public final class BrailleInputManager {
    
    /// Shared singleton instance.
    public static let shared = BrailleInputManager()
    
    /// The set of braille dots (1-6) currently accumulated in the chord.
    private var currentDots = Set<Int>()
    
    /// The specific physical keys currently held down.
    private var pressedKeys = Set<Int>()
    
    /// Mapping of keyboard key codes to braille dot numbers.
    /// Standard Layout: S=Dot3, D=Dot2, F=Dot1, J=Dot4, K=Dot5, L=Dot6.
    private let keyDotMap: [Int: Int] = [
        3: 1,  // F -> Dot 1
        2: 2,  // D -> Dot 2
        1: 3,  // S -> Dot 3
        38: 4, // J -> Dot 4
        40: 5, // K -> Dot 5
        37: 6  // L -> Dot 6
    ]
    
    /// Private initializer for singleton pattern.
    private init() {}
    
    /// Placeholder for explicit event handling if not routing via `process`
    /// - Returns: Always false currently.
    public func handle(event: NSEvent) -> Bool {
        return false
    }
    
    /// Timer to aggregate rolled key presses into a single chord.
    private var inputTimer: Timer?
    
    /// Processes a raw key event from the Input manager.
    ///
    /// This method tracks key down/up states to determine when a chord is formed and completed.
    /// It uses a short timer to allow for "rolled" chords (where keys are pressed and released asynchronously).
    ///
    /// - Parameters:
    ///   - keyCode: The hardware key code.
    ///   - isDown: Boolean indicating if the key was pressed (`true`) or released (`false`).
    public func process(keyCode: Int, isDown: Bool) {
        if let dot = keyDotMap[keyCode] {
            if isDown {
                pressedKeys.insert(keyCode)
                currentDots.insert(dot)
                
                // Restart timer on every key press to wait for the whole chord
                inputTimer?.invalidate()
                inputTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.submitChord() }
                }
            } else {
                pressedKeys.remove(keyCode)
                // If keys are released but timer hasn't fired, it means we are still typing fast?
                // Actually, traditional logic submits on "All Up".
                // New Logic: Submit on Timer 50ms after last Down.
                // Releasing keys shouldn't trigger submit if timer is pending.
                // If timer fired, we already submitted.
                // If we are holding keys down long?
                // If we want "All Up" as fallback:
                if pressedKeys.isEmpty && !currentDots.isEmpty {
                     // Timer might be running?
                     // If we rely purely on timer, we might double submit if we do this.
                     // Let's rely on timer for speed.
                     // If user presses A, holds, then releases. Timer would have fired 50ms after press.
                     // So character is typed.
                     // If user presses A+B (Chord), A down, B down (reset timer). Timer fires.
                     // So we don't need "All Up" submit anymore if timer handles it.
                }
            }
        } else if keyCode == 49 { // Space
            if !isDown {
               inject(string: " ")
            }
        } else if keyCode == 51 { // Delete
             if !isDown {
                 injectBackspace()
             }
        }
    }
    
    /// Converts the accumulated dots into a character and injects it.
    private func submitChord() {
        // Translation logic
        let char = translate(dots: currentDots)
        currentDots.removeAll()
        if let c = char {
            inject(string: String(c))
        }
    }
    
    /// Translates a set of braille dots into a Grade 1 Braille character.
    ///
    /// - Parameter dots: Set of dot integers (1 through 6).
    /// - Returns: The corresponding `Character`, or `nil` if no mapping exists.
    private func translate(dots: Set<Int>) -> Character? {
        // Basic Grade 1 Table (A-Z)
        // Bitmask construction: Dot 1 = bit 0, Dot 2 = bit 1, etc.
        let mask = dots.reduce(0) { $0 | (1 << ($1 - 1)) }
        
        switch mask {
        case 1: return "a"   // Dot 1
        case 3: return "b"   // Dots 1-2
        case 9: return "c"   // Dots 1-4
        case 25: return "d"  // Dots 1-4-5
        case 17: return "e"  // Dots 1-5
        case 11: return "f"  // Dots 1-2-4
        case 27: return "g"  // Dots 1-2-4-5
        case 19: return "h"  // Dots 1-2-5
        case 10: return "i"  // Dots 2-4
        case 26: return "j"  // Dots 2-4-5
        case 5: return "k"   // Dots 1-3
        case 7: return "l"   // Dots 1-2-3
        case 13: return "m"  // Dots 1-3-4
        case 29: return "n"  // Dots 1-3-4-5
        case 21: return "o"  // Dots 1-3-5
        case 15: return "p"  // Dots 1-2-3-4
        case 31: return "q"  // Dots 1-2-3-4-5
        case 23: return "r"  // Dots 1-2-3-5
        case 14: return "s"  // Dots 2-3-4
        case 30: return "t"  // Dots 2-3-4-5
        case 37: return "u"  // Dots 1-3-6
        case 39: return "v"  // Dots 1-2-3-6
        case 58: return "w"  // Dots 2-4-5-6 (Special unordered case)
        case 45: return "x"  // Dots 1-3-4-6
        case 61: return "y"  // Dots 1-3-4-5-6
        case 53: return "z"  // Dots 1-3-5-6
        default: return nil
        }
    }
    
    /// Synthesizes valid keyboard events to type the translated character.
    ///
    /// - Parameter string: The string to type.
    private func inject(string: String) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else { return }
        var chars = Array(string.utf16)
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        event.setIntegerValueField(.eventSourceUserData, value: Input.voshEventUserData)
        event.post(tap: .cghidEventTap)
        
        guard let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else { return }
        up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        up.post(tap: .cghidEventTap)
        
        // Echo input for feedback (Handled by Input manager via Event Tap)
        // Task { @MainActor in
        //      Output.shared.announce(string)
        // }
    }
    
    /// Synthesizes a backspace key press.
    private func injectBackspace() {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: true)
        event?.post(tap: .cghidEventTap)
        let eventUp = CGEvent(keyboardEventSource: nil, virtualKey: 51, keyDown: false)
        eventUp?.post(tap: .cghidEventTap)
    }
}
