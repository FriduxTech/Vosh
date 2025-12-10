//
//  Command.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation

/// Represents an executable action within the Vosh system.
///
/// Commands encapsulate the logic for specific operations (e.g., "Next Heading", "Read Current Line")
/// allowing for modularity, better testing, and dynamic registration.
@MainActor
protocol Command {
    /// Executes the command logic.
    /// - Parameter agent: The context in which the command executes (VoshAgent).
    func execute(agent: VoshAgent) async
}

/// A flexible command implementation using a closure.
struct BlockCommand: Command {
    private let action: (VoshAgent) async -> Void
    
    init(action: @escaping (VoshAgent) async -> Void) {
        self.action = action
    }
    
    func execute(agent: VoshAgent) async {
        await action(agent)
    }
}

/// A registry for managing available commands.
@MainActor
final class CommandRegistry {
    static let shared = CommandRegistry()
    
    private var commands = [String: Command]()
    
    func register(_ command: Command, for identifier: String) {
        commands[identifier] = command
    }
    
    func execute(_ identifier: String, agent: VoshAgent) async {
        guard let command = commands[identifier] else {
            print("Command not found: \(identifier)")
            return
        }
        await command.execute(agent: agent)
    }
}
