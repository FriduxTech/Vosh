//
//  ElementRole.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// Enumeration of common macOS Accessibility roles (`AXRole`).
///
/// This list represents a type-safe mapping of role strings returned by the Accessibility API.
/// It is not exhaustive but includes the most common UI elements found in standard applications.
public enum ElementRole: String {
    /// The application object itself.
    case application = "AXApplication"
    /// The system-wide accessibility object.
    case systemWide = "AXSystemWide"
    
    // MARK: - Windows & Containers
    
    /// A standard window.
    case window = "AXWindow"
    /// A modal sheet attached to a window.
    case sheet = "AXSheet"
    /// A drawer sliding out from a window (legacy).
    case drawer = "AXDrawer"
    /// An area allowing window resizing.
    case growArea = "AXGrowArea"
    /// A popover bubble.
    case popover = "AXPopover"
    /// A generic group container.
    case group = "AXGroup"
    /// A tab group container.
    case tabGroup = "AXTabGroup"
    /// A split view group.
    case splitGroup = "AXSplitGroup"
    /// A toolbar container.
    case toolbar = "AXToolbar"
    
    // MARK: - Controls
    
    /// A clickable button.
    case button = "AXButton"
    /// A radio button (usually part of a group).
    case radioButton = "AXRadioButton"
    /// A toggleable checkbox.
    case checkBox = "AXCheckBox"
    /// A button that pops up a menu.
    case popUpButton = "AXPopUpButton"
    /// A button that opens a menu.
    case menuButton = "AXMenuButton"
    /// A radio group container.
    case radioGroup = "AXRadioGroup"
    /// A combo box / drop-down list.
    case comboBox = "AXComboBox"
    /// A slider control.
    case slider = "AXSlider"
    /// A stepper/incrementer control.
    case incrementer = "AXIncrementor"
    /// A color picker well.
    case colorWell = "AXColorWell"
    /// A disclosure triangle for expanding/collapsing content.
    case disclosureTriangle = "AXDisclosureTriangle"
    
    // MARK: - Text & Content
    
    /// An image or graphic.
    case image = "AXImage"
    /// A single line editable text field.
    case textField = "AXTextField"
    /// A multi-line editable text area.
    case textArea = "AXTextArea"
    /// Non-editable static text label.
    case staticText = "AXStaticText"
    /// A text heading.
    case heading = "AXHeading"
    /// A time editing field.
    case timeField = "AXTimeField"
    /// A date editing field.
    case dateField = "AXDateField"
    /// A help tag or tooltip.
    case helpTag = "AXHelpTag"
    
    // MARK: - Lists & Tables
    
    /// A table view.
    case table = "AXTable"
    /// A table column.
    case column = "AXColumn"
    /// A table row.
    case row = "AXRow"
    /// An outline view (tree).
    case outline = "AXOutline"
    /// A list view.
    case list = "AXList"
    /// A standard browser view (e.g. Columns view in Finder).
    case browser = "AXBrowser"
    /// A table cell.
    case cell = "AXCell"
    
    // MARK: - Layout & Scrolling
    
    /// A scrollable area.
    case scrollArea = "AXScrollArea"
    /// A scroll bar.
    case scrollBar = "AXScrollBar"
    /// A splitter bar.
    case splitter = "AXSplitter"
    /// A generic matte or background.
    case matte = "AXMatte"
    /// A layout area container.
    case layoutArea = "AXLayoutArea"
    /// An item within a layout area.
    case layoutItem = "AXLayoutItem"
    /// A drag handle.
    case handle = "AXHandle"
    /// A generic grid.
    case grid = "AXGrid"
    /// A ruler.
    case ruler = "AXRuler"
    
    // MARK: - Indicators
    
    /// A value indicator (e.g. progress bar value).
    case valueIndicator = "AXValueIndicator"
    /// A busy/spinner indicator.
    case busyIndicator = "AXBusyIndicator"
    /// A progress bar.
    case progressIndicator = "AXProgressIndicator"
    /// A relevance indicator (e.g. search ranking).
    case relevanceIndicator = "AXRelevanceIndicator"
    /// A level indicator (e.g. signal strength).
    case levelIndicator = "AXLevelIndicator"
    
    // MARK: - Menus
    
    /// The menu bar.
    case menuBar = "AXMenuBar"
    /// An item in the menu bar.
    case menuBarItem = "AXMenuBarItem"
    /// A menu definition.
    case menu = "AXMenu"
    /// An item within a menu.
    case menuItem = "AXMenuItem"
    
    // MARK: - System
    
    /// An item in the Dock.
    case dockItem = "AXDockItem"
    
    // MARK: - Web
    
    /// A hyperlink.
    case link = "AXLink"
    /// A web content area.
    case webArea = "AXWebArea"
    /// A MathML element.
    case math = "AXMath"
    
    // MARK: - Other
    
    /// Unknown role.
    case unknown = "AXUnknown"
}
