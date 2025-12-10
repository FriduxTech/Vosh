//
//  AccessPassThroughReader.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Element
import Output

/// An accessibility reader that "passes through" to its children.
///
/// This reader ignores the container element itself and instead reads the summaries of all its children.
/// This is useful for grouping elements that don't have semantic meaning themselves (e.g., a generic group)
/// but contain meaningful content that should be presented as a single unit or sequence.
@AccessActor class AccessPassThroughReader: AccessGenericReader {
    
    /// Reads and aggregates the summaries of all child elements.
    ///
    /// It attempts to use `childElementsInNavigationOrder` first, falling back to `childElements`.
    ///
    /// - Returns: An array of `OutputSemantic` tokens representing the combined summary of all children.
    override func readSummary() async throws -> [OutputSemantic] {
        let children = if let children = try await element.getAttribute(.childElementsInNavigationOrder) as? [Any?] {
            children
        } else if let children = try await element.getAttribute(.childElements) as? [Any?] {
            children
        } else {
            []
        }
        var content = [OutputSemantic]()
        for child in children.lazy.compactMap({$0 as? Element}) {
            let reader = try await AccessReader(for: child)
            content.append(contentsOf: try await reader.readSummary())
        }
        return content
    }
}
