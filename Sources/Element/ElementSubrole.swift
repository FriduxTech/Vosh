//
//  ElementSubrole.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// Enumeration of common macOS Accessibility subroles (`AXSubrole`).
///
/// Subroles refine the semantic meaning of an element beyond its primary `ElementRole`.
/// For example, a `button` role might have a `closeButton` subrole, indicating strictly distinct behavior.
public enum ElementSubrole: String {
    
    // MARK: - Window Controls
    
    /// The "stoplight" close button in a window title bar.
    case closeButton = "AXCloseButton"
    /// The "stoplight" minimize button in a window title bar.
    case minimizeButton = "AXMinimizeButton"
    /// The "stoplight" zoom/maximize button.
    case zoomButton = "AXZoomButton"
    /// A button explicitly inside a toolbar.
    case toolBarButton = "AXToolbarButton"
    /// A button to toggle full screen mode.
    case fullScreenButton = "AXFullScreenButton"
    
    // MARK: - Window Types
    
    /// A standard application window.
    case standardWindow = "AXStandardWindow"
    /// A dialog or alert window.
    case dialogWindow = "AXDialog"
    /// A high-priority system dialog.
    case systemDialogWindow = "AXSystemDialog"
    /// A utility or palette window that floats above others.
    case floatingWindow = "AXFloatingWindow"
    /// A system-level floating window (e.g. HUD).
    case systemFloatingWindow = "AXSystemFloatingWindow"
    
    // MARK: - Text & Content
    
    /// A text field rendering bullets for passwords.
    case secureTextField = "AXSecureTextField"
    /// A search entry field (often with a magnifying glass icon).
    case searchField = "AXSearchField"
    
    // MARK: - Structure
    
    /// A row within a table.
    case tableRow = "AXTableRow"
    /// A row within an outline view.
    case outlineRow = "AXOutlineRow"
    /// A visual element with no semantic meaning (ignored by screen readers).
    case decorative = "AXDecorative"
    /// A list of content items (e.g. Finder sidebar).
    case contentList = "AXContentList"
    /// A definition list.
    case descriptionList = "AXDescriptionList"
    /// A timeline track (e.g. video editor).
    case timeline = "AXTimeline"
    
    // MARK: - Controls
    
    /// Arrow to increment a value (e.g. stepper).
    case incrementArrow = "AXIncrementArrow"
    /// Arrow to decrement a value.
    case decrementArrow = "AXDecrementArrow"
    /// Page up control in a scrollbar.
    case incrementPage = "AXIncrementPage"
    /// Page down control in a scrollbar.
    case decrementPage = "AXDecrementPage"
    /// A button used to sort a column.
    case sortButton = "AXSortButton"
    /// A star rating or similar indicator.
    case ratingIndicator = "AXRatingIndicator"
    /// A toggle switch (e.g. iOS style switch).
    case toggle = "AXToggle"
    /// A switch control.
    case selector = "AXSwitch"
    
    // MARK: - Dock Items
    
    /// An application icon in the Dock.
    case applicationDockItem = "AXApplicationDockItem"
    /// A document icon in the Dock.
    case documentDockItem = "AXDocumentDockItem"
    /// A folder (stack) icon in the Dock.
    case folderDockItem = "AXFolderDockItem"
    /// A minimized window in the Dock.
    case minimizedWindowDockItem = "AXMinimizedWindowDockItem"
    /// A URL link in the Dock.
    case urlDockItem = "AXURLDockItem"
    /// A miscellaneous Dock item.
    case extraDockItem = "AXDockExtraDockItem"
    /// The Trash icon in the Dock.
    case trashDockItem = "AXTrashDockItem"
    /// A separator line in the Dock.
    case separatorDockItem = "AXSeparatorDockItem"
    /// The Cmd+Tab application switcher list.
    case processSwitcherList = "AXProcessSwitcherList"
    
    // MARK: - Other
    
    /// Unknown or unspecified subrole.
    case unknown = "AXUnknown"
}
