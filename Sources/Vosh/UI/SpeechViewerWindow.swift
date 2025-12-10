//
//  SpeechViewerWindow.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import SwiftUI

/// A standalone window acting as a "visual history" of speech output.
///
/// `SpeechViewerWindow` is designed for sighted users (e.g., developers, assessors, or teachers) to follow along
/// with what Vosh is announcing. It renders text in a high-contrast terminal style.
final class SpeechViewerWindow: NSWindow {
    
    /// The text view displaying the speech log.
    private let textView: NSTextView
    
    /// Initializes the speech viewer window.
    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 300)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        
        // Setup TextView
        let scrollView = NSScrollView(frame: contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        
        textView = NSTextView(frame: contentRect)
        textView.isEditable = false
        textView.isSelectable = true // Allow user to copy text
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.backgroundColor = .black
        textView.textColor = .green
        textView.autoresizingMask = .width
        
        scrollView.documentView = textView
        
        super.init(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        self.title = "Vosh Speech Viewer"
        self.contentView = scrollView
        self.backgroundColor = .black
        self.isOpaque = true
        self.level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow))) // Keep floating above other apps
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        self.center()
    }
    
    /// Appends a new speech entry to the log.
    ///
    /// - Parameter text: The announced text string.
    func append(text: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(text)\n"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: NSColor.green
            ]
            let attributedString = NSAttributedString(string: line, attributes: attrs)
            self.textView.textStorage?.append(attributedString)
            self.textView.scrollToEndOfDocument(nil)
        }
    }
    
    /// Clears the current log content.
    func clear() {
        DispatchQueue.main.async { [weak self] in
             self?.textView.string = ""
        }
    }
}
