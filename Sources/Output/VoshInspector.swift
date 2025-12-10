//
//  VoshInspector.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// A debugging utility window that displays raw accessibility data for the focused element.
///
/// `VoshInspector` provides a floating HUD (Heads-Up Display) useful for developers to inspect
/// the properties, hierarchy, and attribute values of the currently focused UI element in real-time.
@MainActor
public final class VoshInspector {
    
    /// Shared singleton instance.
    public static let shared = VoshInspector()
    
    /// The floating panel window.
    private let panel: NSPanel
    
    /// The text view displaying the inspector content.
    private let textView: NSTextView
    
    /// Initializes the inspector panel.
    private init() {
        panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Vosh Inspector"
        panel.isFloatingPanel = true
        panel.level = .floating
        
        let scrollView = NSScrollView(frame: panel.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        
        textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .white
        textView.backgroundColor = .clear
        
        scrollView.documentView = textView
        panel.contentView = scrollView
    }
    
    /// Toggles the visibility of the inspector window.
    public func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    /// Updates the displayed information.
    ///
    /// - Parameter info: The debug string to display (usually a dump of the focused element).
    public func update(info: String) {
        guard panel.isVisible else { return }
        textView.string = info
    }
}
