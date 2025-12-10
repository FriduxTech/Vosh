//
//  AccessActor.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// A global actor that coordinates all accessibility-related operations.
///
/// This actor ensures that all state changes and event handling within the Access module
/// occur on a consistent execution context, preventing data races and ensuring
/// thread safety for the accessibility subsystem.
@globalActor public actor AccessActor {
    
    /// The shared singleton instance of the actor.
    public static let shared = AccessActor()

    /// Private initializer to enforce singleton usage.
    private init() {}

    /// Executes the given body on the `AccessActor`.
    ///
    /// This is a convenience method to easily run code isolated to this actor.
    ///
    /// - Parameters:
    ///   - resultType: The type of the result returned by the body closure.
    ///   - body: The closure to execute on the actor.
    /// - Returns: The result of the closure execution.
    /// - Throws: Any error thrown by the body closure.
    public static func run<T: Sendable>(resultType _: T.Type = T.self, body run: @AccessActor () throws -> T) async rethrows -> T {
        return try await run()
    }
}
