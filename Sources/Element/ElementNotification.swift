//
//  ElementNotification.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// A type-safe enumeration of standard Accessibility notifications (Events).
///
/// Use these values to subscribe to changes in the UI state, such as focus movement,
/// window creation, or value updates. These map directly to the `AXNotification` constant strings.
public enum ElementNotification: String {
    
    // MARK: - Focus
    
    /// The focused window has changed.
    case windowDidGetFocus = "AXFocusedWindowChanged"
    
    /// The focused UI element within the application has changed.
    case elementDidGetFocus = "AXFocusedUIElementChanged"

    // MARK: - Application State
    
    /// The application was activated (became frontmost).
    case applicationDidBecomeActive = "AXApplicationActivated"
    
    /// The application was deactivated (another app became frontmost).
    case applicationDidBecomeInactive = "AXApplicationDeactivated"
    
    /// The application was hidden.
    case applicationDidHide = "AXApplicationHidden"
    
    /// The application was unhidden.
    case applicationDidShow = "AXApplicationShown"

    // MARK: - Windows & Sheets
    
    /// A new window was created/opened.
    case windowDidAppear = "AXWindowCreated"
    
    /// A window was moved.
    case windowDidMove = "AXWindowMoved"
    
    /// A window was resized.
    case windowDidResize = "AXWindowResized"
    
    /// A window was minimized (miniaturized).
    case windowDidMinimize = "AXWindowMiniaturized"
    
    /// A window was restored from minimized state.
    case windowDidRestore = "AXWindowDeminiaturized"
    
    /// A drawer was opened.
    case drawerDidSpawn = "AXDrawerCreated"
    
    /// A sheet (modal dialog) was opened.
    case sheetDidSpawn = "AXSheetCreated"
    
    /// A help tag (tooltip) was displayed.
    case helpTagDidSpawn = "AXHelpTagCreated"

    // MARK: - Menus
    
    /// A menu was opened.
    case menuDidOpen = "AXMenuOpened"
    
    /// A menu was closed.
    case menuDidClose = "AXMenuClosed"
    
    /// A menu item was selected (highlighted/traversed).
    case menuDidSelectItem = "AXMenuItemSelected"

    // MARK: - Tables & Outlines
    
    /// The number of rows in a table/list changed.
    case rowCountDidUpdate = "AXRowCountChanged"
    
    /// A row was expanded (in an outline).
    case rowDidExpand = "AXRowExpanded"
    
    /// A row was collapsed.
    case rowDidCollapse = "AXRowCollapsed"
    
    /// The selection of cells changed.
    case cellSelectionDidUpdate = "AXSelectedCellsChanged"
    
    /// The selection of rows changed.
    case rowSelectionDidUpdate = "AXSelectedRowsChanged"
    
    /// The selection of columns changed.
    case columnSelectionDidUpdate = "AXSelectedColumnsChanged"

    // MARK: - General Element Changes
    
    /// A generic element was created.
    case elementDidAppear = "AXCreated"
    
    /// An element was destroyed.
    case elementDidDisappear = "AXUIElementDestroyed"
    
    /// The busy state of an element changed.
    case elementBusyStatusDidUpdate = "AXElementBusyChanged"
    
    /// An element was resized.
    case elementDidResize = "AXResized"
    
    /// An element was moved.
    case elementDidMove = "AXMoved"
    
    /// Selected children (e.g., icons in Finder) were moved.
    case selectedChildrenDidMove = "AXSelectedChildrenMoved"
    
    /// The set of selected children changed.
    case childrenSelectionDidUpdate = "AXSelectedChildrenChanged"
    
    /// Text selection changed within a text element.
    case textSelectionDidUpdate = "AXSelectedTextChanged"
    
    /// The title of an element changed.
    case titleDidUpdate = "AXTitleChanged"
    
    /// The value of an element changed.
    case valueDidUpdate = "AXValueChanged"

    // MARK: - Layout
    
    /// The units used by the application changed.
    case unitsDidUpdate = "AXUnitsChanged"
    
    /// A generic layout change occurred.
    case layoutDidChange = "AXLayoutChanged"

    // MARK: - Announcements
    
    /// The application requested a spoken announcement (VoiceOver specific).
    case applicationDidAnnounce = "AXAnnouncementRequested"
    
    // MARK: - Web
    
    /// A web page finished loading.
    case loadComplete = "AXLoadComplete"
}

/// Keys used in the user-info payload of an notification/event.
public enum PayloadKey: String {
    
    /// The text content of an announcement notification.
    case announcement = "AXAnnouncement"
}
