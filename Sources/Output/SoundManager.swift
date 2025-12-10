//
//  SoundManager.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit

/// Manages system sound effects feedback.
///
/// `SoundManager` provides a layer of abstraction over `NSSound` (and potentially `AVAudioPlayer`
/// in the future for custom assets), allowing Vosh to play earcons representing semantic events
/// like boundaries, errors, or success confirmations.
@MainActor public final class SoundManager {
    
    /// Shared singleton instance.
    public static let shared = SoundManager()
    
    /// Private initializer.
    private init() {}
    
    /// Enumeration of semantic sound types.
    public enum SoundType {
        /// Hit a boundary (e.g., start/end of file).
        case boundary
        /// Generic click (e.g., toggled switch).
        case click
        /// Error or invalid action.
        case error
        /// Successful action completion.
        case success
        /// Item deleted.
        case delete
        /// Textural feedback (e.g., rapid indent changes).
        case texture
        /// Level/Context change (e.g., entering group).
        case levelChange
        /// Simple beep.
        case beep
    }
    
    /// Plays the sound effect associated with the given semantic type.
    ///
    /// Currently maps to system sounds (e.g. "Pop", "Tink", "Basso").
    /// In a production environment, this would likely load custom Vosh-specific audio resources.
    ///
    /// - Parameter type: The semantic type of sound to play.
    public func play(_ type: SoundType) {
        let soundName: String
        switch type {
        case .boundary:
            soundName = "Pop"
        case .click:
            soundName = "Tink"
        case .error:
            soundName = "Basso"
        case .success:
            soundName = "Glass"
        case .delete:
             soundName = "Purr"
        case .texture:
             soundName = "Frog"
        case .levelChange:
             soundName = "Bottle"
        case .beep:
             soundName = "Tink"
        }
        
        if let sound = NSSound(named: soundName) {
            sound.play()
        } else {
             // Fallback if system sound is missing
             NSSound.beep()
        }
    }
}
