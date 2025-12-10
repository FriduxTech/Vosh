//
//  AccessFocus.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import Element
import Output

/// Represents the state of the user's accessibility focus.
///
/// This struct holds the focused `AccessEntity` and its associated `AccessReader`,
/// facilitating both interaction and info-gathering (like reading voiceover output) whenever focus changes.
@AccessActor public struct AccessFocus {
    
    /// The entity currently holding the focus.
    public let entity: AccessEntity
    
    /// The reader responsible for generating output (speech/braille) for the focused entity.
    public let reader: AccessReader

    /// Creates a new focus state for the specified accessibility element.
    ///
    /// This convenience initializer wraps the `Element` in an `AccessEntity` automatically.
    ///
    /// - Parameter element: The element to focus.
    public init(on element: Element) async throws {
        let entity = try await AccessEntity(for: element)
        try await self.init(on: entity)
    }

    /// Unique identifier for this focus state.
    public let id = UUID()

    /// Creates a new focus state for the specified entity.
    ///
    /// Initializes the appropriate `AccessReader` for the entity type.
    ///
    /// - Parameter entity: The entity to focus.
    public init(on entity: AccessEntity) async throws {
        self.entity = entity
        reader = try await AccessReader(for: entity.element)
    }
}
extension AccessFocus: Identifiable {}
