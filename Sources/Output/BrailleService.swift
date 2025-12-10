//
//  BrailleService.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Cocoa

/// Manages Braille output via an on-screen visual proxy (Virtual Braille Display).
///
/// `BrailleService` translates standard text into Braille patterns (using a basic Grade 1 translation table)
/// and displays it in a floating HUD window. This simulates a refreshable Braille display for development
/// or for sighted users debugging accessibility.
@MainActor
public final class BrailleService {
    
    /// Shared singleton instance.
    public static let shared = BrailleService()
    
    /// The window controller responsible for displaying the braille HUD.
    private let window = BrailleWindow()
    
    /// Current state of the braille display (enabled/visible or disabled/hidden).
    public private(set) var isEnabled = false
    
    /// Private initializer.
    private init() {}
    
    /// Toggles the visibility of the Braille output window.
    public func toggle() {
        isEnabled.toggle()
        if isEnabled {
            window.show()
            window.display("Braille On")
        } else {
            window.hide()
        }
    }
    
    /// Displays text on the virtual Braille display.
    ///
    /// If the service is disabled, this method does nothing.
    /// The text is first translated into Braille characters before being displayed.
    ///
    /// - Parameter text: The text to translate and display.
    public func output(_ text: String) {
        guard isEnabled else { return }
        let braille = translate(text)
        window.display(braille)
    }
    
    /// Simple dictionary mapping characters to their Braille unicode equivalents (Grade 1/Uncontracted).
    private let brailleMap: [Character: String] = [
        "a": "⠁", "b": "⠃", "c": "⠉", "d": "⠙", "e": "⠑", "f": "⠋", "g": "⠛", "h": "⠓", "i": "⠊", "j": "⠚",
        "k": "⠅", "l": "⠇", "m": "⠍", "n": "⠝", "o": "⠕", "p": "⠏", "q": "⠟", "r": "⠗", "s": "⠎", "t": "⠞",
        "u": "⠥", "v": "⠧", "w": "⠺", "x": "⠭", "y": "⠽", "z": "⠵",
        "1": "⠼⠁", "2": "⠼⠃", "3": "⠼⠉", "4": "⠼⠙", "5": "⠼⠑", "6": "⠼⠋", "7": "⠼⠛", "8": "⠼⠓", "9": "⠼⠊", "0": "⠼⠚",
        " ": " ", ",": "⠂", ";": "⠆", ":": "⠒", ".": "⠲", "!": "⠖", "(": "⠶", ")": "⠶", "?": "⠦", "\"": "⠶",
        "'": "⠄", "-": "⠤",
        // Formatters
        "A": "⠠⠁", "B": "⠠⠃", "C": "⠠⠉", "D": "⠠⠙", "E": "⠠⠑", "F": "⠠⠋", "G": "⠠⠛", "H": "⠠⠓", "I": "⠠⠊", "J": "⠠⠚",
        "K": "⠠⠅", "L": "⠠⠇", "M": "⠠⠍", "N": "⠠⠝", "O": "⠠⠕", "P": "⠠⠏", "Q": "⠠⠟", "R": "⠠⠗", "S": "⠠⠎", "T": "⠠⠞",
        "U": "⠠⠥", "V": "⠠⠧", "W": "⠠⠺", "X": "⠠⠭", "Y": "⠠⠽", "Z": "⠠⠵"
    ]
    
    // Add property to store the current table type
    public var translationTable: String = "English Grade 1"

    /// Translates a string into Grade 1 Braille.
    ///
    /// - Parameter text: The input string.
    /// - Returns: A string containing Braille Unicode characters.
    private func translate(_ text: String) -> String {
        // TODO: Integrate LibLouis for Grade 2 (Contracted) Braille.
        // For now, we only support basic Grade 1 (Uncontracted).
        
        if translationTable.contains("Grade 2") {
            // Placeholder: In a real implementation, call LibLouis here.
            // For this MVP, we warn the user via the display that Grade 2 isn't ready.
            // But we fallback to Grade 1 silently to keep it usable.
        }
        
        return text.map { char in
            if let mapped = brailleMap[char] {
                return mapped
            }
            if char.isUppercase, let lowerMapped = brailleMap[Character(char.lowercased())] {
                return "⠠" + lowerMapped
            }
            return String(char)
        }.joined()
    }
}

/// A floating HUD window simulating a hardware Braille display.
final class BrailleWindow: NSWindowController {
    
    /// The label displaying text.
    private let label = NSTextField(labelWithString: "Braille Output")
    
    /// Initializes the panel.
    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 80),
            styleMask: [.hudWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.title = "Braille Display"
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Configures the visual appearance of the label.
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        label.font = NSFont.monospacedSystemFont(ofSize: 24, weight: .bold)
        label.textColor = .green
        label.alignment = .center
        label.frame = contentView.bounds
        label.autoresizingMask = [.width, .height]
        contentView.addSubview(label)
    }
    
    /// Shows the window.
    func show() {
        window?.orderFront(nil)
    }
    
    /// Hides the window.
    func hide() {
        window?.orderOut(nil)
    }
    
    /// Udpates the text content.
    func display(_ text: String) {
        label.stringValue = text
    }
}
