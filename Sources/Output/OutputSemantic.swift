//
//  OutputSemantic.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// Type-safe semantic descriptions of accessibility events and element states.
///
/// `OutputSemantic` values encapsulate the *meaning* of an accessibility update (e.g., "entered a table",
/// "value changed to 'foo'", "selected"). These tokens are processed by the `Output` engine to determine
/// the exact speech string, sound effect, or haptic pattern to render, allowing for customizable feedback styles.
public enum OutputSemantic {
    
    // MARK: - Structural
    
    /// The application name (e.g., on switch).
    case application(String)
    
    /// The window title.
    case window(String)
    
    /// A generic boundary (start/end of list, etc.).
    case boundary
    
    /// Count of items in a selection.
    case selectedChildrenCount(Int)
    
    /// Total rows in a table/grid.
    case rowCount(Int)
    
    /// Total columns in a table/grid.
    case columnCount(Int)
    
    // MARK: - Content
    
    /// The primary accessibility label/name of an element.
    case label(String)
    
    /// The localized role description (e.g., "button").
    case role(String)
    
    /// A boolean value (e.g., checkbox state).
    case boolValue(Bool)
    
    /// An integer value.
    case intValue(Int64)
    
    /// A floating point value (e.g., slider).
    case floatValue(Double)
    
    /// A string value (e.g., text field content).
    case stringValue(String)
    
    /// A URL value.
    case urlValue(String)
    
    /// Placeholder text.
    case placeholderValue(String)
    
    // MARK: - Text Editing
    
    /// Selected text content.
    case selectedText(String)
    
    /// Additional text added to selection.
    case selectedTextGrew(String)
    
    /// Text removed from selection.
    case selectedTextShrank(String)
    
    /// Text just inserted by typing.
    case insertedText(String)
    
    /// Text just deleted.
    case removedText(String)
    
    /// Help tag / tool tip.
    case help(String)
    
    /// An updated label value (live region).
    case updatedLabel(String)
    
    // MARK: - State Flags
    
    /// Element has been edited.
    case edited
    
    /// Element is currently selected.
    case selected
    
    /// Element is disabled/dimmed.
    case disabled
    
    /// Element is expanded (e.g. disclosure triangle).
    case expanded
    
    /// Element is collapsed.
    case collapsed
    
    // MARK: - Navigation Context
    
    /// Entering a container group.
    case entering
    
    /// Exiting a container group.
    case exiting
    
    /// Moved to next element.
    case next
    
    /// Moved to previous element.
    case previous
    
    /// No element has focus.
    case noFocus
    
    // MARK: - System
    
    /// Caps Lock state changed.
    case capsLockStatusChanged(Bool)
    
    /// Accessibility API is disabled for the target.
    case apiDisabled
    
    /// Target is not accessible.
    case notAccessible
    
    /// Application timed out.
    case timeout
    
    // MARK: - Formatting (Phase 3)
    
    /// Indentation level change (number of spaces/tabs).
    case indentation(Int)
    
    /// Sequence of repeated spaces.
    case repeatedSpaces(Int)
    
    /// Misspelled word detected.
    case misspelling
    
    /// Text styling attributes changed (bold, font, etc.).
    case textAttributesChanged
}
