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
        // Optimized O(N) approach using Swift's fast string comparisons
        
        let newCount = newText.count
        let previousCount = previousText.count
        
        // Quick check for complete mismatch
        if newText.isEmpty { 
            previousText = newText
            return "Cleared" // Or empty?
        }
        
        // Overlap usually means:
        // previousText: [ A B C ]
        // newText:      [ B C D ]
        // Suffix of prev matches Prefix of new.
        
        // We assume substantial overlap in a terminal scroll context.
        // We can check from the end of previousText backwards.
        
        // Heuristic: If we can match a significant chunk, accepted.
        // We find the longest common substring rooted at End of Prev and Start of New.
        
        // Strategy: 
        // 1. commonSuffix calculation is expensive if unguided.
        // 2. We assume the *new content* is appended.
        // 3. We assume some old content scrolled off the top.
        
        // Check if `newText` contains `previousText` (Simple Append) - Handled above by hasPrefix check (which is O(1)/O(K)).
        // We already checked hasPrefix.
        
        // Check overlap.
        // Iterate possible overlap lengths.
        let maxOverlap = min(previousCount, newCount)
        var overlap = 0
        
        // Optimization: Use suffix check on previousText?
        // Let's assume lines. Terminal updates are line-based.
        // But we have raw string.
        
        // We use Swift's `hasPrefix` iteratively? No, slow.
        // Use Collection.difference? Very slow for large text.
        
        // We use a simple loop but optimistically.
        // Most updates are append small, so overlap is large.
        // Check if `newText` starts with a suffix of `previousText`.
        
        // Try largest overlap first? (Previous text just shifted up)
        // If we shifted 1 line up, overlap is (Total - 1 line).
        
        // Optimized Scan:
        // Only check if matching chars.
        // Convert to Array for indexing speed if re-used, but string views are okay.
        // Actually, just find the *new* text.
        // New text is the suffix of `newText` that is NOT in overlap.
        
        // Let's try to find where `previousText` ends inside `newText`? No, other way around.
        // We want to find a suffix of `active previous` that matches a prefix of `active new`.
        
        // Using `commonPrefix` logic:
        // We want to find largest K such that previousText.suffix(K) == newText.prefix(K)?
        // NO.
        // Scroll:
        // Prev: Line1\nLine2
        // New:  Line2\nLine3
        // Overlap is "Line2". 
        // Prev.suffix(5) == New.prefix(5).
        
        // So yes, we want largest K.
        // Iterating K from maxOverlap down to 1.
        
        // SPEED UP:
        // Check commonHash? No.
        // Check last char of prev match inside new?
        // Let's use a reasonable range. If no overlap found within X chars, assume full replace?
        // AccessActor isn't main thread, so some CPU is okay, but we want responsiveness.
        
        // Start from max overlap (best case = little scroll).
        let pChars = Array(previousText)
        let nChars = Array(newText)
        
        // Use local Arrays for speed
        for k in stride(from: min(pChars.count, nChars.count), through: 1, by: -1) {
             // Check boundary chars first to avoid slice alloc
             if pChars[pChars.count - k] == nChars[0] {
                 // Potential match start, verify full slice
                 // Slice compare is fast
                 if pChars[(pChars.count - k)...] == nChars[0..<k] {
                     overlap = k
                     break
                 }
             }
        }
        
        previousText = newText
        
        if overlap > 0 {
            let diff = nChars[overlap..<newCount]
            return String(diff)
        }
        
        return newText
    }
}
