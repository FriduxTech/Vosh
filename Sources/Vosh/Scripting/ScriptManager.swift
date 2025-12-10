//
//  ScriptManager.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import Output

/// Manages the execution of user scripts and custom commands.
///
/// `ScriptManager` provides a lightweight interpreted environment for automating Vosh tasks.
/// Currently supports a basic set of commands (echo, speak, delay) with plans for advanced integration (Python/Lua).
@MainActor
public final class ScriptManager {
    
    /// Shared singleton instance.
    public static let shared = ScriptManager()
    
    /// Initializes the script manager.
    private init() {}
    
    /// Executes a single script command string.
    ///
    /// Parses the input string for a command verb and arguments, executes the corresponding logic,
    /// and returns a status or output string.
    ///
    /// Supported Commands:
    /// - `echo <text>`: Returns the text.
    /// - `speak <text>`: Synthesizes speech immediately.
    /// - `delay <seconds>`: Pauses execution (async).
    /// - `version`: Returns the scripting engine version.
    /// - `help`: Lists available commands.
    ///
    /// - Parameter command: The command string to parse and run.
    /// - Returns: The string output of the command, or an error message.
    public func execute(command: String) async -> String {
        let components = command.split(separator: " ", maxSplits: 1).map { String($0) }
        guard !components.isEmpty else { return "" }
        
        let cmd = components[0].lowercased()
        let args = components.count > 1 ? components[1] : ""
        
        switch cmd {
        case "echo":
            return args.replacingOccurrences(of: "\"", with: "")
            
        case "help":
            return "Commands: echo <text>, speak <text>, delay <seconds>, version"
            
        case "version":
            return "Vosh Scripting v0.2"
            
        case "speak":
            // speak "Hello world"
            let text = args.replacingOccurrences(of: "\"", with: "")
            await Output.shared.announce(text)
            return "Speaking..."
            
        case "delay":
            // delay 1.5
            if let seconds = Double(args) {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return "Delayed \(seconds)s"
            }
            return "Invalid duration"
            
        default:
            return "Unknown command: \(cmd)"
        }
    }
    
    /// Loads and executes a script file line-by-line.
    ///
    /// - Parameter path: The absolute file path to the script.
    public func runScriptFile(at path: String) async {
        await Output.shared.announce("Running script: \(URL(fileURLWithPath: path).lastPathComponent)")
        
        let fileContent = await Task.detached {
            try? String(contentsOfFile: path)
        }.value
        
        guard let content = fileContent else {
            await Output.shared.announce("Failed to read file")
            return
        }
        
        // Execute line by line
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let result = await execute(command: line)
            // Optional: Log result of each line if needed
            _ = result
        }
    }
}
