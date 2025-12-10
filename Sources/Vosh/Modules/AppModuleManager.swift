//
//  AppModuleManager.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import Access

/// The central registry and coordinator for application-specific logic modules.
///
/// `AppModuleManager` listens for application switching events and activates
/// the corresponding `AppModule` if one is registered for the active bundle identifier.
/// This allows Vosh to swap interaction behaviors seamlessly as the user navigates between apps.
@MainActor public final class AppModuleManager {
    
    /// Shared singleton instance.
    public static let shared = AppModuleManager()
    
    /// Dictionary of registered modules keyed by Bundle Identifier.
    private var modules = [String: AppModule]()
    
    /// The currently valid behavior module for the frontmost application (if any).
    public private(set) var activeModule: AppModule?
    
    /// Initializes the manager and registers default built-in modules.
    private init() {
        register(FinderModule())
        register(SafariModule())
        register(MailModule())
        register(TerminalModule())
    }
    
    /// Registers a custom module provider.
    /// - Parameter module: The module instance conforming to `AppModule`.
    public func register(_ module: AppModule) {
        modules[module.bundleIdentifier] = module
    }
    
    /// Updates the active module based on the newly activated application.
    ///
    /// - Parameter app: The `NSRunningApplication` that just became frontmost.
    public func applicationDidActivate(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier else { return }
        if let module = modules[id] {
            activeModule = module
        } else {
            activeModule = nil
        }
    }
}
