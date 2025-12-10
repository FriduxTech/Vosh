//
//  TerminalModule.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Access
import AppKit
import Output
import Input
import Element

/// An application module specialized for Terminal interaction.
///
/// `TerminalModule` reduces verbosity when interacting with command-line interfaces,
/// suppressing intermediate scroll area announcements and simplifying the initial focus feedback.
final class TerminalModule: AppModule {
    
    /// Target Bundle ID: `com.apple.Terminal`.
    let bundleIdentifier = "com.apple.Terminal"
    
    /// Handles focus changes within Terminal.
    ///
    /// Silences scroll area notifications and provides a summarized "Terminal Active" announcement
    /// instead of reading the entire visible buffer upon window focus.
    ///
    /// - Parameter focus: The new focus state.
    /// - Returns: `true` if the standard announcement was suppressed/handled, `false` otherwise.
    func onFocus(_ focus: AccessFocus) async -> Bool {
        let element = await focus.entity.element
        let role = try? await element.getAttribute(.role) as? ElementRole
        
        // Suppress "Scroll Area" intermediate container announcements
        if role == .scrollArea {
            return true
        }
        
        // Handle the main terminal text grid
        if role == .textArea {
            // Avoid reading the entire buffer content automatically on focus.
            // Just announce context.
            await Output.shared.announce("Terminal Active")
            return true
        }
        
        return false
    }
}
