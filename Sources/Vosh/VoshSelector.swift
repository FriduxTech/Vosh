//
//  VoshSelector.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import Output

/// Enumeration of available Rotor (Selector) navigation modes.
///
/// These options determine how the user navigates through content when using the Rotor commands
/// (Up/Down arrows in standard Vosh navigation).
enum VoshSelectorOption: String, CaseIterable {
    /// Standard DOM/UI tree navigation.
    case navigation = "Navigation"
    /// Navigate by text lines.
    case lines = "Lines"
    /// Navigate by words.
    case words = "Words"
    /// Navigate by characters.
    case characters = "Characters"
    /// Navigate by headings (Web/Document).
    case headings = "Headings"
    /// Navigate by hyperlinks.
    case links = "Links"
    /// Navigate by button elements.
    case buttons = "Buttons"
    /// Navigate between open windows.
    case windows = "Windows"
    
    /// User-visible description for announcement.
    var description: String { rawValue }
}

/// Manages the state of the "Rotor" or "Selector" control.
///
/// `VoshSelector` allows the user to cycle through different navigation granularity settings
/// (e.g., Characters, Words, Headings). The `VoshAgent` queries the `currentOption` to decide
/// what action to perform when the user triggers a navigation command (e.g. Up/Down swipe).
@MainActor final class VoshSelector {
    
    /// The predefined list of available selector options.
    /// In the future, this could be user-configurable.
    private let options: [VoshSelectorOption] = VoshSelectorOption.allCases
    
    /// The index of the currently active option.
    private var currentIndex: Int = 0
    
    /// The currently selected Rotor option.
    var currentOption: VoshSelectorOption {
        options[currentIndex]
    }
    
    /// Cycles to the next option in the list (wrapping around).
    /// Triggers an announcement of the new selection.
    func next() {
        currentIndex = (currentIndex + 1) % options.count
        announce()
    }
    
    /// Cycles to the previous option in the list (wrapping around).
    /// Triggers an announcement of the new selection.
    func previous() {
        currentIndex = (currentIndex - 1 + options.count) % options.count
        announce()
    }
    
    /// Speaks the name of the currently selected option using the `Output` system.
    private func announce() {
        Output.shared.announce(currentOption.description)
    }
}
