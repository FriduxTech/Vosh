//
//  VoshHUD.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// A visual "Heads-Up Display" (HUD) overlay for Vosh.
///
/// `VoshHUD` presents spoken announcements visually on the screen in a large, high-contrast panel.
/// This aids sighted developers in debugging feedback and provides captions for sighted users who
/// may be observing an accessibility session.
///
/// The HUD appears briefly when an announcement is made and fades out automatically.
@MainActor final class VoshHUD {
    
    /// The transparent overlay panel.
    private var window: NSPanel?
    
    /// The text label displaying the current message.
    private var textField: NSTextField?
    
    /// Timer handling the auto-hide delay.
    private var fadeTimer: Timer?
    
    /// Shared singleton instance.
    static let shared = VoshHUD()
    
    /// Private initializer.
    private init() {
        setupWindow()
    }
    
    /// Configures the visual appearance and behavior of the HUD window.
    private func setupWindow() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 600, height: 100),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        
        panel.level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let textField = NSTextField(labelWithString: "")
        textField.textColor = .white
        textField.font = NSFont.systemFont(ofSize: 32, weight: .bold)
        textField.alignment = .center
        textField.drawsBackground = false
        textField.isBezeled = false
        textField.isEditable = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        panel.contentView?.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: panel.contentView!.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: panel.contentView!.centerYAnchor),
            textField.widthAnchor.constraint(equalTo: panel.contentView!.widthAnchor, constant: -40)
        ])
        
        self.textField = textField
        self.window = panel
        
        centerWindow()
    }
    
    /// Resets the window position to the bottom center of the screen.
    private func centerWindow() {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let windowRect = window.frame
        
        // Center horizontally, position near bottom vertically
        let x = screenRect.midX - (windowRect.width / 2)
        let y = screenRect.minY + 150
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    /// Shows a message on the HUD, resetting the fade timer.
    ///
    /// - Parameter message: The text string to display.
    func show(_ message: String) {
        guard let window = window, let textField = textField else { return }
        
        // Cancel existing fade to keep it visible for new message
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        textField.stringValue = message
        window.alphaValue = 1.0
        window.orderFront(nil)
        
        // Auto-fade after delay
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fadeOut()
            }
        }
    }
    
    /// Animates the window opacity to 0.
    private func fadeOut() {
        guard let window = window else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            window.animator().alphaValue = 0.0
        } completionHandler: {
             // window.orderOut(nil) // Optional, keep hidden
        }
    }
}
