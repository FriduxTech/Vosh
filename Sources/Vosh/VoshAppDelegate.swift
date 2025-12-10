//
//  VoshAppDelegate.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import Output

/// The Application Delegate managing the lifecycle of the Vosh screen reader.
///
/// `AppDelegate` handles the initialization of the core `VoshAgent` upon launch and ensures
/// proper cleanup and announcements upon termination. It also manages the system status menu.
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// The main Vosh agent instance controlling accessibility logic.
    private var agent: VoshAgent?
    
    /// Controller for the system menu bar item.
    private var menu: VoshMenu?

    /// Called when the application has finished launching.
    ///
    /// This method kicks off the asynchronous initialization of the `VoshAgent`.
    /// - Parameter notification: The notification object (unused).
    func applicationDidFinishLaunching(_ notification: Notification) {
        Output.shared.announce("Starting Vosh")
        
        Task { [self] in
            // Initialize the agent asynchronously (may require permission checks)
            let agent = await VoshAgent()
            
            await MainActor.run { [self] in
                self.agent = agent
                // Initialize menu only after agent is possibly ready? Or always?
                // Logic here initializes it regardless, but keeps reference.
                self.menu = VoshMenu()
            }
            
            if agent == nil {
                Output.shared.announce("Vosh failed to start! Please check Accessibility Permissions.")
                // Wait for speech to finish before terminating
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                NSApplication.shared.terminate(nil)
            } else {
                // Determine if we should greet
                Task {
                    await agent?.announceGreeting()
                }
            }
        }
    }

    /// Handles the application termination request.
    ///
    /// Allows the app to announce "Goodbye" (via `VoshAgent` logic or fallback here) before exiting.
    /// - Parameter app: The application instance.
    /// - Returns: `.terminateNow` if ready, or `.terminateCancel` to delay for cleanup/speech.
    func applicationShouldTerminate(_ app: NSApplication) -> NSApplication.TerminateReply {
        if agent != nil {
            // If agent exists, we might want to let it handle the shutdown flow (e.g. confirmation).
            // However, if we reached here, the user likely used Cmd+Q or System Menu.
            
            // Clear agent to prevent re-entry loops if needed, or just flag.
            agent = nil
            Output.shared.announce("Vosh Terminating")
            
            Task {
                // Allow some time to announce termination before actually terminating.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    NSApplication.shared.reply(toApplicationShouldTerminate: true)
                }
            }
            // Cancel immediate termination to allow async task to run
            return .terminateLater
        }
        return .terminateNow
    }
}
