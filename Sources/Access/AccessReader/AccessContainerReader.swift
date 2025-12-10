//
//  AccessContainerReader.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Element
import Output

/// A specialized accessibility reader for container elements such as tables, lists, and outlines.
///
/// This reader enhances the generic element reading capabilities by adding context specific
/// to containers, such as row/column counts and selected item details.
@AccessActor class AccessContainerReader: AccessGenericReader {
    
    /// Generates the full accessibility response for the container.
    ///
    /// Combines the standard generic output (title, role, etc.) with information about
    /// the currently selected children within the container.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    override func read() async throws -> [OutputSemantic] {
        var content = try await super.read()
        content.append(contentsOf: try await readSelectedChildren())
        return content
    }

    /// Generates a summary of the container, including collection metadata.
    ///
    /// Adds row and column counts to the standard summary if they are available.
    ///
    /// - Returns: An array of `OutputSemantic` tokens summarising the container.
    override func readSummary() async throws -> [OutputSemantic] {
        var content = try await super.readSummary()
        if let rows = try await element.getAttribute(.rows) as? [Any?] {
            content.append(.rowCount(rows.count))
        }
        if let columns = try await element.getAttribute(.columns) as? [Any?] {
            content.append(.columnCount(columns.count))
        }
        return content
    }

    /// Fetches and reads information about selected child elements.
    ///
    /// Identifies selection via multiple attributes (`selectedChildrenElements`, `selectedCells`, etc.).
    /// If a single item is selected, it reads the summary of that item.
    /// If multiple items are selected, it returns a count.
    ///
    /// - Returns: An array of `OutputSemantic` tokens describing the selection.
    private func readSelectedChildren() async throws -> [OutputSemantic] {
        let children = if let children = try await element.getAttribute(.selectedChildrenElements) as? [Any?], !children.isEmpty {
            children.compactMap({$0 as? Element})
        } else if let children = try await element.getAttribute(.selectedCells) as? [Any?] {
            children.compactMap({$0 as? Element})
        } else if let children = try await element.getAttribute(.selectedRows) as? [Any?] {
            children.compactMap({$0 as? Element})
        } else if let children = try await element.getAttribute(.selectedColumns) as? [Any?] {
            children.compactMap({$0 as? Element})
        } else {
            [Element]()
        }
        if children.count == 1, let child = children.first {
            let reader = try await AccessReader(for: child)
            return try await reader.readSummary()
        }
        return [.selectedChildrenCount(children.count)]
    }
}
