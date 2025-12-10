//
//  FinderModule.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Access
import AppKit
import Output
import Input
import Element

/// An application module specialized for macOS Finder interaction.
///
/// `FinderModule` enhances the accessibility of the default file manager by recognizing
/// specific Finder UI areas (e.g. Sidebar, Icon View, List View) and potentially
/// providing richer file metadata feedback in the future.
final class FinderModule: AppModule {
    
    /// Target Bundle ID: `com.apple.finder`.
    let bundleIdentifier = "com.apple.finder"
    
    /// Handles focus changes within Finder.
    ///
    /// Currently acts as a pass-through (returns `false`), allowing the standard `Access` logic
    /// to handle announcements. Future implementations could enforce specific reading orders for
    /// Column Views or provide file size/kind details automatically.
    ///
    /// - Parameter focus: The new focus state.
    /// - Returns: `false`, delegating to default Vosh behavior.
    func onFocus(_ focus: AccessFocus) async -> Bool {
        // Finder Specific Logic
        
        // 1. If we focused a Window, search for the content view
        // Check role via element attribute
        if let role = try? await focus.entity.element.getAttribute(.role) as? ElementRole, role == .window {
            if let content = await findContent(root: focus.entity) {
                // Set system focus to the content view (Vosh will pick up the event)
                try? await content.element.setAttribute(.isFocused, value: true)
                return true
            }
        }
        
        return false
    }
    
    /// Recursively searches for the main file view (Outline, Icon, Column/Browser).
    private func findContent(root: AccessEntity) async -> AccessEntity? {
        var queue = [root]
        var scanned = 0
        
        while !queue.isEmpty && scanned < 50 {
            let current = queue.removeFirst()
            scanned += 1
            
            // value of type 'AccessEntity' has no member 'role' -> use element attribute
            // We use raw Attribute lookup. Note: getAttribute returns Any?. ElementRole is Custom.
            // Underlying AX API returns String. Element might auto-convert if return type inferred?
            // Usually returns String or ElementRole if wrapper handles it.
            // Let's safe cast to ElementRole.
            
            if let role = try? await current.element.getAttribute(.role) as? ElementRole {
                if [.outline, .browser, .table, .list].contains(role) {
                    return current
                }
            } else if let roleStr = try? await current.element.getAttribute(.role) as? String {
                // Fallback for AXIconView which might not be in ElementRole
                if roleStr == "AXIconView" { return current }
            }
            
            // children() -> getAttribute(.childElements)
            if let children = try? await current.element.getAttribute(.childElements) as? [Element] {
                for child in children {
                    // Wrap in AccessEntity to continue queue
                    if let entity = try? await AccessEntity(for: child) {
                        queue.append(entity)
                    }
                }
            }
        }
        return nil
    }
}
