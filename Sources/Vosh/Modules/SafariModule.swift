//
//  SafariModule.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Access
import AppKit
import Output
import Input
import Element

/// An application module specialized for Safari interaction.
///
/// `SafariModule` manages the automatic switching between "Browse Mode" (virtual cursor navigation)
/// and "Focus Mode" (direct interaction) based on the user's focus context (e.g., Web Content vs Address Bar).
final class SafariModule: AppModule {
    
    /// Target Bundle ID: `com.apple.Safari`.
    let bundleIdentifier = "com.apple.Safari"
    
    /// Handles focus changes within Safari.
    ///
    /// Automatically enables Browse Mode when entering web content areas and disables it
    /// when focusing the Address Bar or other chrome UI controls.
    ///
    /// - Parameter focus: The new focus state.
    /// - Returns: `false`, allowing the standard Vosh announcement to proceed after mode switching.
    @MainActor
    func onFocus(_ focus: AccessFocus) async -> Bool {
        let element = await focus.entity.element
        
        // Auto-switch modes based on role
        // AXWebArea -> Browse Mode
        // AXTextField (Address Bar) -> Focus Mode
        
        guard let role = try? await element.getAttribute(.role) as? ElementRole else { return false }
        
        if role == .webArea || role == .group {
             // Web content often appears as group or webarea
             if !Input.shared.browseModeEnabled {
                 Input.shared.browseModeEnabled = true
                 Output.shared.announce("Browse Mode")
             }
        } else if role == .textField || role == .textArea {
             // Address Bar OR Web Input -> Focus Mode
             // We want to type in any text field.
             if Input.shared.browseModeEnabled {
                 Input.shared.browseModeEnabled = false
                 Output.shared.announce("Focus Mode")
             }
        }
        
        return false // Allow standard announcement of the focused element
    }
}
