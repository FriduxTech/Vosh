//
//  ElementAttribute.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// A type-safe representation of standard Accessibility attributes.
///
/// These values correspond to keys used in the Apple Accessibility API (`AXAttribute`).
/// Using this enum prevents stringly-typed errors when querying or setting element properties.
public enum ElementAttribute: String {
    
    // MARK: - Informational
    
    /// The role (type) of the element, e.g., "AXButton".
    case role = "AXRole"
    
    /// The subrole of the element, offering more specific classification, e.g., "AXCloseButton".
    case subrole = "AXSubrole"
    
    /// A localized, human-readable description of the element's role.
    case roleDescription = "AXRoleDescription"
    
    /// The title of the element.
    case title = "AXTitle"
    
    /// An extended accessibility description, often used for detailed VoiceOver text.
    case description = "AXDescription"
    
    /// Contextual help text explaining the element's function.
    case help = "AXHelp"

    // MARK: - Hierarchical
    
    /// The parent element in the accessibility tree.
    case parentElement = "AXParent"
    
    /// The list of direct child elements.
    case childElements = "AXChildren"
    
    /// The list of child elements sorted in the logical keyboard navigation order.
    case childElementsInNavigationOrder = "AXChildrenInNavigationOrder"
    
    /// The subset of children currently selected.
    case selectedChildrenElements = "AXSelectedChildren"
    
    /// The subset of children currently visible on screen.
    case visibleChildrenElements = "AXVisibleChildren"
    
    /// The window containing this element.
    case windowElement = "AXWindow"
    
    /// The top-level UI container (often the window or a floating panel).
    case topLevelElement = "AXTopLevelUIElement"
    
    /// An element that serves as the title/label for this element.
    case titleElement = "AXTitleUIElement"
    
    /// An element for which this element serves as the title/label.
    case servesAsTitleForElement = "AXServesAsTitleForUIElement"
    
    /// Related elements that don't share a direct parent-child relationship.
    case linkedElements = "AXLinkedUIElements"
    
    /// Elements that share focus state with this one.
    case sharedFocusElements = "AXSharedFocusElements"
    
    /// The nearest ancestor capable of accepting keyboard focus.
    case focusableAncestor = "AXFocusableAncestor"

    // MARK: - Visual State
    
    /// Whether the element is interactive and enabled.
    case isEnabled = "AXEnabled"
    
    /// Whether the element currently has keyboard focus.
    case isFocused = "AXFocused"
    
    /// The screen position of the element (CGPoint).
    case position = "AXPosition"
    
    /// The size of the element (CGSize).
    case size = "AXSize"

    // MARK: - Values
    
    /// The current value of the element (type varies by role).
    case value = "AXValue"
    
    /// A human-readable text representation of the value.
    case valueDescription = "AXValueDescription"
    
    /// The minimum allowed value (e.g., for sliders).
    case minValue = "AXMinValue"
    
    /// The maximum allowed value (e.g., for sliders).
    case maxValue = "AXMaxValue"
    
    /// The precision or step size for value adjustments.
    case valueIncrement = "AXValueIncrement"
    
    /// Whether the value wraps around (e.g., in a spinner).
    case valueWraps = "AXValueWraps"
    
    /// A list of allowed values for the element.
    case allowedValues = "AXAllowedValues"
    
    /// Placeholder text displayed when the value is empty.
    case placeholderValue = "AXPlaceholderValue"

    // MARK: - Text Content
    
    /// The currently selected text substring.
    case selectedText = "AXSelectedText"
    
    /// The range of the currently selected text.
    case selectedTextRange = "AXSelectedTextRange"
    
    /// Multiple non-contiguous text selection ranges.
    case selectedTextRanges = "AXSelectedTextRanges"
    
    /// The range of text visible within the element's bounds.
    case visibleTextRange = "AXVisibleTextRange"
    
    /// The total character count of the text content.
    case numberOfCharacters = "AXNumberOfCharacters"
    
    /// Elements sharing text content with this one.
    case sharedTextElements = "AXSharedTextUIElements"
    
    /// The character range shared with other elements.
    case sharedCharacteRange = "AXSharedCharacterRange"
    
    /// The line number where the insertion point (caret) is located.
    case insertionPointLineNumber = "AXInsertionPointLineNumber"

    // MARK: - Window & App Structure
    
    /// Whether this is the main window of the application.
    case isMain = "AXMain"
    
    /// Whether the window is currently minimized.
    case isMinimized = "AXMinimized"
    
    /// The window's close button.
    case closeButton = "AXCloseButton"
    
    /// The window's zoom (maximize/restore) button.
    case zoomButton = "AXZoomButton"
    
    /// The window's minimize button.
    case minimizeButton = "AXMinimizeButton"
    
    /// The window's toolbar button/container.
    case toolbar = "AXToolbarButton"
    
    /// The window's full-screen toggle button.
    case fullScreenButton = "AXFullScreenButton"
    
    /// The proxy icon (document icon in title bar).
    case proxy = "AXProxy"
    
    /// The resize handle/area of the window.
    case growArea = "AXGrowArea"
    
    /// Whether the window is modal (blocks interaction with other windows).
    case isModal = "AXModal"
    
    /// The default button in a dialog (triggered by Enter).
    case defaultButton = "AXDefaultButton"
    
    /// The cancel button in a dialog (triggered by Esc).
    case cancelButton = "AXCancelButton"

    // MARK: - Menus
    
    /// The command character for a menu item shortcut.
    case menuItemCmdChar = "AXMenuItemCmdChar"
    
    /// The virtual key code for a menu item shortcut.
    case menuItemCmdVirtualKey = "AXMenuItemCmdVirtualKey"
    
    /// The glyph representing a special key (like arrow keys) for a shortcut.
    case menuItemCmdGlyph = "AXMenuItemCmdGlyph"
    
    /// The modifier keys required for the menu item shortcut.
    case menuItemCmdModifiers = "AXMenuItemCmdModifiers"
    
    /// The checkmark or bullet character for a selected menu item.
    case menuItemMarkChar = "AXMenuItemMarkChar"
    
    /// The primary content element of the menu item.
    case menuItemPrimaryElement = "AXMenuItemPrimaryUIElement"

    // MARK: - Application
    
    /// The application's main menu bar.
    case menuBar = "AXMenuBar"
    
    /// All open windows of the application.
    case windows = "AXWindows"
    
    /// The currently frontmost (active) window.
    case frontmostWindow = "AXFrontmost"
    
    /// Whether the application is hidden.
    case hidden = "AXHidden"
    
    /// The main window (legacy, often same as `isMain` on the window itself).
    case mainWindow = "AXMainWindow"
    
    /// The focused window of the application.
    case focusedWindow = "AXFocusedWindow"
    
    /// The specific element currently holding keyboard focus.
    case focusedElement = "AXFocusedUIElement"
    
    /// The extras menu bar (e.g., status items).
    case extrasMenuBar = "AXExtrasMenuBar"

    // MARK: - Tables & Lists
    
    /// The rows within a table or list.
    case rows = "AXRows"
    
    /// The subset of rows currently visible.
    case visibleRows = "AXVisibleRows"
    
    /// The currently selected rows.
    case selectedRows = "AXSelectedRows"
    
    /// The columns within a table.
    case columns = "AXColumns"
    
    /// The subset of columns currently visible.
    case visibleColumns = "AXVisibleColumns"
    
    /// The currently selected columns.
    case selectedColumns = "AXSelectedColumns"
    
    /// The currently selected cells.
    case selectedCells = "AXSelectedCells"
    
    /// The sort direction of a column (Ascending, Descending).
    case sortDirection = "AXSortDirection"
    
    /// The header elements for table columns.
    case columnHeaderElements = "AXColumnHeaderUIElements"
    
    /// The index of a row or column.
    case index = "AXIndex"
    
    /// Whether a row is currently disclosing its children (in an outline).
    case disclosing = "AXDisclosing"
    
    /// The rows disclosed by this row (children).
    case disclosedRows = "AXDisclosedRows"
    
    /// The parent row that disclosed this row.
    case disclosedByRow = "AXDisclosedByRow"

    // MARK: - Specific Roles
    
    /// References the horizontal scroll bar.
    case horizontalScrollBar = "AXHorizontalScrollBar"
    
    /// References the vertical scroll bar.
    case verticalScrollBar = "AXVerticalScrollBar"
    
    /// The orientation of the element (e.g., horizontal slider).
    case orientation = "AXOrientation"
    
    /// The header of an interface group.
    case header = "AXHeader"
    
    /// Whether the document has unsaved changes.
    case edited = "AXEdited"
    
    /// The tabs within a tab group.
    case tabs = "AXTabs"
    
    /// The overflow button for a toolbar.
    case overflowButton = "AXOverflowButton"
    
    /// The filename associated with the element (e.g., proxy icon).
    case fileName = "AXFilenameAttribute"
    
    /// Whether an outline item or disclosure triangle is expanded.
    case expanded = "AXExpanded"
    
    /// Whether a selectable item is selected.
    case selected = "AXSelected"
    
    /// The split dividers in a split group.
    case splitters = "AXSplitters"
    
    /// The contents of an element.
    case contents = "AXContents"
    
    /// The next logical set of contents (pagination).
    case nextContents = "AXNextContents"
    
    /// The previous logical set of contents (pagination).
    case previousContents = "AXPreviousContents"
    
    /// The document reference.
    case document = "AXDocument"
    
    /// The incrementer control (stepper up arrow).
    case incrementer = "AXIncrementer"
    
    /// The decrement button of a stepper.
    case decrementButton = "AXDecrementButton"
    
    /// The increment button of a stepper.
    case incrementButton = "AXIncrementButton"
    
    /// The title of a column.
    case columnTitle = "AXColumnTitle"
    
    /// The URL associated with a link or web area.
    case url = "AXURL"
    
    /// The label value (distinct from title in some contexts).
    case labelValue = "AXLabelValue"
    
    /// The menu element currently being shown by this control.
    case shownMenuElement = "AXShownMenuUIElement"
    
    /// The application that owns the focused element.
    case focusedApplication = "AXFocusedApplication"
    
    /// Whether the element is currently busy/processing.
    case elementBusy = "AXElementBusy"
    
    /// Whether alternate UI is visible (e.g. holding Option key).
    case alternateUIVisible = "AXAlternateUIVisible"
    
    /// Whether the application is running.
    case isApplicationRunning = "AXIsApplicationRunning"
    
    /// Search field cancel button.
    case searchButton = "AXSearchButton"
    
    /// Search field clear button.
    case clearButton = "AXClearButton"
    
    // MARK: - Live Regions
    
    /// The status of a live region (polite, assertive, off).
    case liveRegionStatus = "AXLiveRegionStatus"
    
    /// The relevant changes for a live region (additions, text, all).
    case liveRegionRelevant = "AXLiveRegionRelevant"

    // MARK: - Indicators
    
    /// The warning threshold for a level indicator.
    case warningValue = "AXWarningValue"
    
    /// The critical threshold for a level indicator.
    case criticalValue = "AXCriticalValue"
    
    // MARK: - Semantics (Math)
    
    /// The MathML content string.
    case mathML = "AXMathML"
    
    /// The radicand of a root (e.g. 'x' in sqrt(x)).
    case mathRootRadicand = "AXMathRootRadicand"
    
    /// The index of a root (e.g. '3' in cbrt(x)).
    case mathRootIndex = "AXMathRootIndex"
    
    /// The numerator of a fraction.
    case mathFractionNumerator = "AXMathFractionNumerator"
    
    /// The denominator of a fraction.
    case mathFractionDenominator = "AXMathFractionDenominator"
    
    /// The base of a power or log.
    case mathBase = "AXMathBase"
    
    /// The subscript content.
    case mathSubscript = "AXMathSubscript"
    
    /// The superscript content.
    case mathSuperscript = "AXMathSuperscript"
    
    /// Content under an expression (limits, etc).
    case mathUnder = "AXMathUnder"
    
    /// Content over an expression.
    case mathOver = "AXMathOver"
}
