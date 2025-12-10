//
//  AccessReader.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Element
import Output

/// The public interface for reading accessibility elements.
///
/// `AccessReader` acts as a factory and facade for specific reader strategies.
/// Based on the role of the element (e.g., Table, Row, or Generic), it instantiates
/// the appropriate underlying strategy (`AccessGenericReader` or a subclass) and delegates
/// all reading operations to it.
@AccessActor public final class AccessReader {
    
    /// The specialized internal strategy used to read the element.
    let strategy: AccessGenericReader

    /// Initializes a reader for the specified element.
    ///
    /// Automatically selects the best reader strategy based on the element's role.
    /// - `.row`, `.column`, `.cell` -> `AccessPassThroughReader`
    /// - `.outline`, `.table` -> `AccessContainerReader`
    /// - Other -> `AccessGenericReader`
    ///
    /// - Parameter element: The element to read.
    public init(for element: Element) async throws {
        if let role = try await element.getAttribute(.role) as? ElementRole {
            switch role {
            case .row, .column, .cell:
                strategy = try await AccessPassThroughReader(for: element)
            case .outline, .table:
                strategy = try await AccessContainerReader(for: element)
            default:
                strategy = try await AccessGenericReader(for: element)
            }
        } else {
            strategy = try await AccessGenericReader(for: element)
        }
    }

    /// Reads the full accessibility content of the element.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    public func read() async throws -> [OutputSemantic] {
        return try await strategy.read()
    }

    /// Reads a concise summary of the element.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    public func readSummary() async throws -> [OutputSemantic] {
        return try await strategy.readSummary()
    }

    /// Reads the accessibility label of the element.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    public func readLabel() async throws -> [OutputSemantic] {
        return try await strategy.readLabel()
    }

    /// Reads the value of the element.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    public func readValue() async throws -> [OutputSemantic] {
        return try await strategy.readValue()
    }

    /// Reads the accessibility role description of the element.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    public func readRole() async throws -> [OutputSemantic] {
        return try await strategy.readRole()
    }

    /// Reads the state of the element.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    public func readState() async throws -> [OutputSemantic] {
        return try await strategy.readState()
    }

    /// Reads the help text of the element.
    ///
    /// - Returns: An array of `OutputSemantic` tokens.
    public func readHelp() async throws -> [OutputSemantic] {
        return try await strategy.readHelp()
    }
}
