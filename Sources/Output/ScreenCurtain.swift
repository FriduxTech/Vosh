//
//  ScreenCurtain.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// Manages the "Screen Curtain" feature which completely blacks out the display for privacy.
///
/// `ScreenCurtain` creates full-screen black overlay windows on all active screens,
/// positioned at the `.screenSaver` window level to obscure all content while still passing
/// through mouse events (if desired, though currently `ignoresMouseEvents = true` passes them through).
@MainActor final class ScreenCurtain {
    
    /// List of overlay windows currently active (one per screen).
    private var windows = [NSWindow]()
    
    /// Toggles the Screen Curtain state.
    var isEnabled: Bool = false {
        didSet {
            // Avoid redundant state changes
            if isEnabled != oldValue {
                if isEnabled {
                    enable()
                } else {
                    disable()
                }
            }
        }
    }
    
    /// Enables the curtain by creating black overlay windows on all screens.
    private func enable() {
        guard windows.isEmpty else { return }
        
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.backgroundColor = .black
            // .screenSaver level ensures it covers almost everything (including Dock and Menu Bar usually)
            window.level = .screenSaver
            // Allow mouse clicks to pass through to underlying applications
            window.ignoresMouseEvents = true
            // Ensure it persists across Spaces and doesn't interfere with window cycling
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
    
    /// Disables the curtain by closing all overlay windows.
    private func disable() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
    }
}
