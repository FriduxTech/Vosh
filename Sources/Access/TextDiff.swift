//
//  TextDiff.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation

/// A utility to calculate specific text changes for output reading.
///
/// `TextDiff` is designed to handle dynamic text updates, particularly in scrolling buffers
/// like Terminals or logs, where the system reports the entire visible text rather than just the change.
public struct TextDiffResult {
    /// The new text that should be spoken.
    public let newContent: String
    /// Whether the change was a simple append (true) or a replacement/scroll (false).
    public let isAppend: Bool
}

public actor TextDiff {
    
    private var previousText: String = ""
    private var lastUpdate: Date = Date.distantPast
    
    public init() {}
    
    /// Resets the diff engine state (e.g. on context change).
    public func reset() {
        previousText = ""
        lastUpdate = Date.distantPast
    }
    
    /// Processes new text and returns the semantic difference.
    ///
    /// - Parameter newText: The current full text content.
    /// - Returns: The string containing only the new information.
    public func process(_ newText: String) -> String {
        // 1. Exact match / No change
        if newText == previousText {
            return ""
        }
        
        // 2. Simple Append (New text starts with old text)
        if newText.hasPrefix(previousText) {
            let diff = String(newText.dropFirst(previousText.count))
            previousText = newText
            return diff
        }
        
        // 3. Scroll / Overlap Detection
        // The screen scrolled up. The bottom of 'previousText' matches the top of 'newText'.
        // We look for the largest overlap.
        
        // Optimization: Use a quick check for suffix/prefix
        // If the text is very large, this could be slow, but for UI strings it's fine.
        // Terminals might have ~2000 chars.
        
        let oldChars = Array(previousText)
        let newChars = Array(newText)
        
        // Bound the search to reasonable visual overlap (e.g. at least 10 chars or 10%)
        // We verify from the longest possible overlap down to 0.
        
        let maxOverlap = min(oldChars.count, newChars.count)
        var bestOverlapLength = 0
        
        // We assume substantial overlap in a scroll.
        // We start checking if old suffix matches new prefix.
        // Check largest possible overlap first (greedy).
        
        // Heuristic: Limits to prevent O(N^2) on huge strings if necessary, 
        // but simple loop is O(N) comparisons where match fits.
        // Actually strict suffix-prefix check is inefficient if done naively.
        // Swift strings are fast enough for UI buffers.
        
        for len in stride(from: maxOverlap, through: 1, by: -1) {
            // Check if suffix of old (last len) == prefix of new (first len)
            let oldStart = oldChars.count - len
            
            // Slice comparison
            // ArraySlice conforms to Equatable
            if oldChars[oldStart..<oldChars.count] == newChars[0..<len] {
                bestOverlapLength = len
                break
            }
        }
        
        // Update state
        previousText = newText
        
        if bestOverlapLength > 0 {
            // Return only the non-overlapping part (the new bottom lines)
            return String(newChars[bestOverlapLength..<newChars.count])
        }
        
        // 4. Complete Replacement
        // If no overlap, return clear + new text?
        // Or just new text.
        return newText
    }
}
