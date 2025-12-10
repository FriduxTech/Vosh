//
//  FocusRingWindow.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// A transparent overlay window that draws a colored border around a specific area of the screen.
///
/// `FocusRingWindow` is used to visually indicate the currently focused element (System Focus)
/// or the current review cursor position to sighted users or developers.
/// It ignores all mouse events and floats above other windows.
final class FocusRingWindow: NSWindow {
    
    /// Initializes a new focus ring window with a specific border color.
    /// - Parameter color: The color of the focus ring border.
    init(color: NSColor) {
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        self.backgroundColor = .clear
        self.level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .moveToActiveSpace, .fullScreenAuxiliary, .ignoresCycle]
        
        let view = FocusRingView(color: color)
        self.contentView = view
    }
    
    /// Updates the window's position and size to match the target rectangle.
    ///
    /// - Parameter rect: The screen coordinates (Cocoa bottom-left origin) of the element to highlight.
    func update(rect: CGRect) {
        // AX Coordinates: Origin Top-Left of Primary Screen.
        // Cocoa Coordinates: Origin Bottom-Left of Primary Screen.
        // Standard conversion: Cocoa.y = ScreenHeight - AX.y - AX.height
        
        let primaryHeight = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height ?? 0
        
        var cocoaRect = rect
        cocoaRect.origin.y = primaryHeight - rect.origin.y - rect.height
        
        self.setFrame(cocoaRect, display: true)
        self.componentView.needsDisplay = true
    }
    
    /// Accessor for the custom content view.
    var componentView: FocusRingView {
        return self.contentView as! FocusRingView
    }
}

/// A custom view responsible for drawing the thick colored border.
final class FocusRingView: NSView {
    
    /// The border color.
    let color: NSColor
    
    /// Initializes the view with a border color.
    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    /// Draws the focus ring border.
    override func draw(_ dirtyRect: NSRect) {
        color.setStroke()
        let path = NSBezierPath(rect: bounds)
        path.lineWidth = 4.0
        path.stroke()
    }
}
