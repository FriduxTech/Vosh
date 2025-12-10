//
//  InputWindow.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// A modal dialog utility for requesting simple text input from the user.
///
/// `InputWindow` provides a convenience method to display a native macOS alert with a text field,
/// blocking execution until the user provides input or cancels.
/// Typically used for search queries, renaming items, or confirming actions.
@MainActor
public struct InputWindow {
    
    /// Presents a modal input dialog to the user.
    ///
    /// - Parameters:
    ///   - title: The main title of the dialog.
    ///   - prompt: The descriptive text or question.
    /// - Returns: The entered string if "OK" was clicked, or `nil` if "Cancel" was selected or the dialog was dismissed.
    public static func requestInput(title: String, prompt: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = inputField
        alert.window.initialFirstResponder = inputField
        
        // Modal execution blocks the main thread loop for this window context
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            return inputField.stringValue
        }
        return nil
    }
}
