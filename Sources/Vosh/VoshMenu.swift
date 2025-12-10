//
//  VoshMenu.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import Output

/// Context Menu controller for the Vosh status bar item.
///
/// `VoshMenu` creates and manages the 'V' icon in the macOS menu bar, providing quick access to
/// Settings, Developer Tools (Inspector, Logger), and Quitting the application.
@MainActor
final class VoshMenu: NSObject {
    
    /// The system status item (icon/button in the menu bar).
    private var statusItem: NSStatusItem!
    
    /// Initializes the menu and attaches it to the system status bar.
    override init() {
        super.init()
        setupMenu()
    }
    
    /// Configures the status item layout and menu options.
    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "V"
            // Use a template image if available for dark/light mode support
            // but text "V" works for MVP.
        }
        
        let menu = NSMenu()
        menu.addItem(withTitle: "Vosh Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Toggle Inspector", action: #selector(toggleInspector), keyEquivalent: "i")
        menu.addItem(withTitle: "Toggle Logger", action: #selector(toggleLogger), keyEquivalent: "o")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Vosh", action: #selector(quit), keyEquivalent: "q")
        
        statusItem.menu = menu
    }
    
    /// Opens the Settings window.
    @objc private func openSettings() {
        SettingsWindow.shared.show()
    }
    
    /// Toggles the Accessibility Inspector window.
    @objc private func toggleInspector() {
        VoshInspector.shared.toggle()
    }
    
    /// Toggles the Speech Logger window.
    @objc private func toggleLogger() {
        SpeechLogger.shared.toggle()
    }
    
    /// Terminates the Vosh application.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
