//
//  Vosh.swift
//  Vosh
//
//  Created by Vosh Team.
//

import SwiftUI

/// The main application entry point and root scene.
///
/// `Vosh` initializes the SwiftUI application lifecycle. It uses a `MenuBarExtra` to provide
/// a discreet system menu interface, keeping the main screen reading functionality running
/// in the background without a persistent dock icon or main window.
@main struct Vosh: App {
    
    /// The application delegate handling system app lifecycle events (launch, termination, etc.).
    /// This bridges the SwiftUI lifecycle to the traditional efficient `NSApplicationDelegate`.
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    /// The top-level scene definition.
    var body: some Scene {
        MenuBarExtra("Vosh", systemImage: "eye") {
            Button(action: { NSApplication.shared.terminate(nil) }, label: { Text("Exit") })
        }
    }
}
