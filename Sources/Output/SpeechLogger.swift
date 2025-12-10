//
//  SpeechLogger.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// A debugging utility panel that records and displays a history of spoken announcements.
///
/// `SpeechLogger` provides a scrollable text view containing timestamped entries for every
/// phrase spoken by Vosh. This is useful for verifying output accuracy without relying solely on audio,
/// or for reviewing past announcements during development.
@MainActor
public final class SpeechLogger {
    
    /// Shared singleton instance.
    public static let shared = SpeechLogger()
    
    /// The floating utility panel window.
    private let panel: NSPanel
    
    /// The text view displaying the log.
    private let textView: NSTextView
    
    /// Private initializer configuring the UI.
    private init() {
        panel = NSPanel(
            contentRect: NSRect(x: 520, y: 100, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Vosh Speech Log"
        panel.isReleasedWhenClosed = false
        
        let scrollView = NSScrollView(frame: panel.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        
        textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = .labelColor
        
        scrollView.documentView = textView
        panel.contentView = scrollView
    }
    
    /// Toggles the visibility of the log window.
    public func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    /// Appends a new entry to the speech log.
    ///
    /// - Parameter text: The text string that was announced.
    public func log(_ text: String) {
        // Optimization: Only update UI if visible, but ideally we'd back this with a buffer if history retrieval was needed.
        guard panel.isVisible else { return }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(text)\n"
        
        if let string = textView.textStorage {
            let attrString = NSAttributedString(string: line, attributes: [.foregroundColor: NSColor.labelColor, .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
            string.append(attrString)
            textView.scrollToEndOfDocument(nil)
        }
    }
}
