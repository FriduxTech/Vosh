//
//  SearchableListWindow.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import Access

/// A reusable modal window displaying a searchable list of string items.
///
/// `SearchableListWindow` provides a standard UI pattern for browsing lists like "Links", "Headings", or "Windows".
/// It features a search field that filters the list in real-time and allows keyboard navigation and selection.
@MainActor
final class SearchableListWindow: NSWindowController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate, NSSearchFieldDelegate {
    
    /// The window title.
    private let title: String
    
    /// The comprehensive list of all items.
    private let items: [String]
    
    /// The currently displayed filtered list.
    private var filteredItems: [String]
    
    /// Async completion handler invoked when a user makes a selection.
    /// Returns the index of the selected item in the *original* `items` array.
    private var selectionHandler: ((Int) async -> Void)?
    
    /// The table view displaying the items.
    private var tableView: NSTableView!
    
    /// The search filter input field.
    private var searchField: NSSearchField!
    
    /// Initializes the searchable list window.
    ///
    /// - Parameters:
    ///   - title: Title displayed in the window header.
    ///   - items: Array of strings to display.
    ///   - handler: Callback to execute with the selected index upon confirmation.
    init(title: String, items: [String], handler: @escaping (Int) async -> Void) {
        self.title = title
        self.items = items
        self.filteredItems = items
        self.selectionHandler = handler
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        
        super.init(window: window)
        
        setupUI(in: window.contentView!)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Configures the internal view hierarchy.
    private func setupUI(in view: NSView) {
        // Search Field
        searchField = NSSearchField(frame: NSRect(x: 20, y: 350, width: 460, height: 30))
        searchField.delegate = self
        searchField.placeholderString = "Filter..."
        searchField.autoresizingMask = [.width, .minYMargin]
        view.addSubview(searchField)
        
        // Table View
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 20, width: 460, height: 320))
        scroll.hasVerticalScroller = true
        scroll.autoresizingMask = [.width, .height]
        
        tableView = NSTableView(frame: scroll.bounds)
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Col1"))
        col.title = title
        col.width = 440
        tableView.addTableColumn(col)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil // Hide header
        
        scroll.documentView = tableView
        view.addSubview(scroll)
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return filteredItems[row]
    }
    
    // MARK: - NSSearchFieldDelegate (Control Text Did Change)
    
    /// Filters the list based on search text input.
    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSSearchField {
            let text = field.stringValue
            if text.isEmpty {
                filteredItems = items
            } else {
                filteredItems = items.filter { $0.localizedCaseInsensitiveContains(text) }
            }
            tableView.reloadData()
            if !filteredItems.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            }
        }
    }
    
    // MARK: - Actions
    
    /// Displays the window and focuses the search field.
    func show() {
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.makeFirstResponder(searchField)
    }

    // MARK: - NSSearchFieldDelegate (Key Handling)
    
    /// Handles keyboard navigation within the search field to control the table list.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let row = tableView.selectedRow
            if row < filteredItems.count - 1 {
                tableView.selectRowIndexes(IndexSet(integer: row + 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(row + 1)
                // Semantic announcement would happen via Access/Output observing selection change naturally
            }
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let row = tableView.selectedRow
            if row > 0 {
                tableView.selectRowIndexes(IndexSet(integer: row - 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(row - 1)
            }
            return true
        } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            let row = tableView.selectedRow
            if row >= 0 && row < filteredItems.count {
                handleSelection(row)
            }
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
             self.window?.close()
             return true
        }
        return false
    }
    
    /// Processes the user selection and triggers the callback.
    private func handleSelection(_ row: Int) {
        // Find original index
        let item = filteredItems[row]
        if let originalIndex = items.firstIndex(of: item) {
             Task {
                 await selectionHandler?(originalIndex)
             }
        }
        self.window?.close()
    }
}
