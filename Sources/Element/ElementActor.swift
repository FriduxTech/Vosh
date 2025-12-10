//
//  ElementActor.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation

/// A global actor that forces all low-level element interactions to run on a shared concurrent pool but isolated context.
///
/// `ElementActor` protects the state of the Element wrappers. Since `AXUIElement` is generally thread-safe,
/// we simply use a standard actor (running on the default concurrent executor) rather than a dedicated serial thread.
/// This reduces overhead and complexity.
@globalActor public actor ElementActor {
    
    /// The singleton instance of the actor.
    public static let shared = ElementActor()
    
    /// Private initializer to enforce singleton usage.
    private init() {}

    /// Executes a closure on the `ElementActor` isolated context.
    public static func run<T: Sendable>(resultType _: T.Type = T.self, body run: @ElementActor () throws -> T) async rethrows -> T {
        return try await run()
    }
}
