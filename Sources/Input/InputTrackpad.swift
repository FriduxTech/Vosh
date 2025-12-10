//
//  InputTrackpad.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// Manages Trackpad gesture input for Vosh command triggers.
///
/// `InputTrackpad` monitors global gesture events (like rotation and swipes) to trigger
/// accessibility commands, such as rotor navigation.
///
/// - Note: Detailed multi-touch gestures (e.g. specific finger taps) are limited by public global `NSEvent` APIs.
/// Deeper integration would require private frameworks (MultitouchSupport) or lower-level event taps.
@MainActor public final class InputTrackpad {
    
    /// Shared singleton instance.
    public static let shared = InputTrackpad()
    
    /// The global event monitor object token.
    private var monitor: Any?
    
    /// Callback closure invoked when a recognized gesture occurs.
    public var onGesture: ((GestureType) -> Void)?
    
    /// Enumeration of supported trackpad custom gestures.
    public enum GestureType {
        /// Single-finger tap (Placeholder/Not fully implemented via public API).
        case tapOneFinger
        /// Two-finger tap (Placeholder).
        case tapTwoFinger
        /// Four-finger tap (Placeholder).
        case tapFourFinger
        /// Three-finger swipe up.
        case swipeUpThreeFinger
        /// Three-finger swipe down.
        case swipeDownThreeFinger
        /// Rotation clockwise (e.g., Rotor Next).
        case rotateClockwise
        /// Rotation counter-clockwise (e.g., Rotor Previous).
        case rotateCounterClockwise
    }
    
    /// Private initializer setting up the global event monitor.
    private init() {
        setupMonitor()
    }
    
    /// Configures the `NSEvent` global monitor for gesture events.
    private func setupMonitor() {
        // Global monitor for gestures.
        // Requires the app to be trusted for accessibility.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.magnify, .rotate, .swipe, .gesture]) { [weak self] event in
             self?.handle(event)
        }
    }
    
    /// Processes incoming gesture events and triggers the callback.
    ///
    /// - Parameter event: The `NSEvent` received from the system.
    private func handle(_ event: NSEvent) {
        switch event.type {
        case .rotate:
             // Rotation values are in degrees. Positive is CCW usually, but checking deltas.
             // Thresholding prevents accidental triggers.
             if event.rotation > 1.0 {
                 onGesture?(.rotateCounterClockwise)
             } else if event.rotation < -1.0 {
                 onGesture?(.rotateClockwise)
             }
        case .swipe:
             // Swipe events (often 3-finger swipes depending on System Preferences).
             if event.deltaY > 0 {
                 onGesture?(.swipeUpThreeFinger)
             } else if event.deltaY < 0 {
                 onGesture?(.swipeDownThreeFinger)
             }
        default: break
        }
    }
}
