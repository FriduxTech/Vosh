//
//  AppModule.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Access

/// Defines a custom behavior profile for a specific application.
///
/// `AppModule` allows developers to create specialized interaction logic for applications
/// that may behave non-standardly (e.g. Finder, Terminal, Web Browsers).
/// It provides hooks to override default focus handling and announcements.
public protocol AppModule {
    
    /// The target Bundle Identifier (e.g. "com.apple.finder") this module supports.
    var bundleIdentifier: String { get }
    
    /// Delegate method invoked when Vosh detects a focus change within the target application.
    ///
    /// - Parameter focus: The new focus state containing the entity and ancestry.
    /// - Returns: `true` if this module has handled the feedback (suppressing Vosh's default announcement),
    ///            or `false` to fall back to the standard behavior.
    func onFocus(_ focus: AccessFocus) async -> Bool
}
