//
//  AccessGenericReader.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import OSLog

import Element
import Output

/// The base accessibility reader class.
///
/// `AccessGenericReader` provides the default implementation for reading accessibility elements.
/// It systematically retrieves and composes semantic output from standard attributes like
/// title, value, role, state, and help text.
@AccessActor class AccessGenericReader {
    
    /// The element being read.
    let element: Element
    
    /// Logger for identifying unhandled value types or issues.
    private static let logger = Logger()

    /// Initializes a generic reader for the specified element.
    ///
    /// - Parameter element: The `Element` to read.
    init(for element: Element) async throws {
        self.element = element
    }

    /// Generates the full accessibility content for the element.
    ///
    /// This method aggregates the summary (label/value), role, state, and help information.
    /// Subclasses may override this to provide specialized reading logic.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    func read() async throws -> [OutputSemantic] {
        var content = try await readSummary()
        content.append(contentsOf: try await readRole())
        content.append(contentsOf: try await readState())
        content.append(contentsOf: try await readPosition()) // NEW
        content.append(contentsOf: try await readHelp())
        return content
    }

    /// Retrieves position information (e.g., "3 of 5") if applicable.
    func readPosition() async throws -> [OutputSemantic] {
        // Only relevant for items in a set (Rows, MenuItems, RadioButtons, etc.)
        guard let role = try? await element.getAttribute(.role) as? ElementRole else { return [] }
        
        let validRoles: Set<ElementRole> = [.row, .menuItem, .radioButton, .cell, .staticText] 
        // staticText included because lists often expose items as text
        
        if validRoles.contains(role) || role == .unknown {
            // Try to get Index
            if let index = try? await element.getAttribute(.index) as? Int {
                // Index is usually 0-based
                let displayIndex = index + 1
                var total = 0
                
                // Try to get total from parent
                if let parent = try? await element.getAttribute(.parentElement) as? Element {
                    // Optimized: Check specific count attributes first
                    if let rows = try? await parent.getAttribute(.rows) as? [Any] {
                        total = rows.count
                    } else if let children = try? await parent.getAttribute(.childElements) as? [Any] {
                        total = children.count
                    }
                }
                
                if total > 0 {
                    return [.stringValue("item \(displayIndex) of \(total)")]
                }
            }
        }
        return []
    }

    /// Generates a concise summary of the element.
    ///
    /// The summary typically consists of the element's label (name) and its current value.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    func readSummary() async throws -> [OutputSemantic] {
        var content = [OutputSemantic]()
        content.append(contentsOf: try await readLabel())
        content.append(contentsOf: try await readValue())
        return content
    }

    /// Retrieves the label (name) of the element.
    ///
    /// It attempts to resolve the label in the following order:
    /// 1. The `title` attribute.
    /// 2. The `titleElement`'s title.
    /// 3. The `description` attribute (fallback).
    ///
    /// - Returns: An array containing the label token, or empty if no label is found.
    func readLabel() async throws -> [OutputSemantic] {
        if let title = try await element.getAttribute(.title) as? String, !title.isEmpty {
            return [.label(title)]
        }
        if let element = try await element.getAttribute(.titleElement) as? Element, let title = try await element.getAttribute(.title) as? String, !title.isEmpty {
            return [.label(title)]
        }
        if let description = try await element.getAttribute(.description) as? String, !description.isEmpty {
            return [.label(description)]
        }
        return []
    }

    /// Retrieves the value of the element.
    ///
    /// Handles various value types including Booleans, Numbers, Strings, and AttributedStrings.
    /// excessive details are handled by specific cases (e.g. selected text within a value).
    ///
    /// - Returns: An array of `OutputSemantic` tokens describing the value.
    func readValue() async throws -> [OutputSemantic] {
        var content = [OutputSemantic]()
        let value: Any? = if let value = try await element.getAttribute(.valueDescription) as? String, !value.isEmpty {
            value
        } else if let value = try await element.getAttribute(.value) {
            value
        } else {
            nil
        }
        guard let value = value else {
            return []
        }
        switch value {
        case let bool as Bool:
            content.append(.boolValue(bool))
        case let integer as Int64:
            content.append(.intValue(integer))
        case let float as Double:
            content.append(.floatValue(float))
        case let string as String:
            content.append(.stringValue(string))
            if let selection = try await element.getAttribute(.selectedText) as? String, !selection.isEmpty {
                content.append(.selectedText(selection))
            }
        case let attributedString as AttributedString:
            let string = String(attributedString.characters)
            content.append(.stringValue(string))
            if let selection = try await element.getAttribute(.selectedText) as? String, !selection.isEmpty {
                content.append(.selectedText(selection))
            }
        case let url as URL:
            content.append(.urlValue(url.absoluteString))
        default:
            Self.logger.warning("Unexpected value type: \(type(of: value), privacy: .public)")
        }
        if let edited = try await element.getAttribute(.edited) as? Bool, edited {
            content.append(.edited)
        }
        if let placeholder = try await element.getAttribute(.placeholderValue) as? String, !placeholder.isEmpty {
            content.append(.placeholderValue(placeholder))
        }
        return content
    }

    /// Retrieves the role description.
    ///
    /// If a description is already present (used as label), the role might be suppressed or redundant.
    /// Otherwise, provides the localized role description.
    ///
    /// - Returns: An array containing the role token.
    func readRole() async throws -> [OutputSemantic] {
        if let description = try await element.getAttribute(.description) as? String, !description.isEmpty {
            return []
        } else if let role = try await element.getAttribute(.roleDescription) as? String, !role.isEmpty {
            return [.role(role)]
        }
        return []
    }

    /// Retrieves the state of the element (Selected, Disabled, etc.).
    ///
    /// - Returns: An array of `OutputSemantic` tokens describing the state.
    func readState() async throws -> [OutputSemantic] {
        var output = [OutputSemantic]()
        if let selected = try await element.getAttribute(.selected) as? Bool, selected {
            output.append(.selected)
        }
        if let enabled = try await element.getAttribute(.isEnabled) as? Bool, !enabled {
            output.append(.disabled)
        }
        return output
    }

    /// Retrieves help text associated with the element.
    ///
    /// - Returns: An array containing the help token.
    func readHelp() async throws -> [OutputSemantic] {
        if let help = try await element.getAttribute(.help) as? String, !help.isEmpty {
            return [.help(help)]
        }
        return []
    }
}
