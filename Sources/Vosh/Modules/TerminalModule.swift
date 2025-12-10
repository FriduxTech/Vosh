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

/// `TerminalModule` reduces verbosity when interacting with command-line interfaces,
/// suppressing intermediate scroll area announcements and simplifying the initial focus feedback.
final class TerminalModule: AppModule {

    /// Target Bundle ID: `com.apple.Terminal`.
    let bundleIdentifier = "com.apple.Terminal"
    
    /// The persistent observer for Terminal content updates.
    private var terminalObserver: ElementObserver?

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
            // We invalidate any previous observer first
            // ElementObserver is @MainActor
            await MainActor.run {
                 self.terminalObserver?.invalidate()
            }
            
            if let observer = try? await ElementObserver(element: element) {
                // Terminal usually updates 'AXValue' or 'AXVisibleText'
                try? await observer.subscribe(to: .valueDidUpdate)
                // Assign on MainActor
                await MainActor.run {
                    self.terminalObserver = observer
                }
                
                // Forward events to Access system or handle them?
                // For now, we ensure it stays alive. 
                // Ideally, we'd hook this into Access.swift's event loop, but TerminalModule 
                // is a specific handler. If we want Access to read it, Access needs to observe it.
                // But this fixes the "Zombie" issue where it died immediately.
            }
            return true
        }
        
        return false
    }
}
