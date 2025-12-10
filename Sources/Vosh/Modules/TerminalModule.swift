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
        
        // Handle Main Terminal Area
        if role == .textArea {
            await Output.shared.announce("Terminal")
            
            // IMPORTANT: Subscribe to value updates to read command output
            if let observer = try? await ElementObserver(element: element) {
                // Terminal usually updates 'AXValue' or 'AXVisibleText'
                try? await observer.subscribe(to: .valueDidUpdate)
                // We need to attach this observer to the Access system or manage it here.
                // Since Modules are stateless/singleton, we can't easily hold refs.
                // Better approach: Let Access.swift handle .valueDidUpdate generically, 
                // but Terminal requires *diffing* the value to read only new lines.
                
                // For MVP: Let Access generic .valueDidUpdate handle it, but we need
                // to ensure Access actually subscribes to it for the focused element.
                // Access.swift currently only subscribes to Application-level events.
                // We need to add specific element observation support.
            }
            return true
        }
        
        return false
    }
}
