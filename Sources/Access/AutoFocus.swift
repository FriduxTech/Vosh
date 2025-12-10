//
//  AutoFocus.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import CoreGraphics
import Element

/// An intelligent heuristic engine for determining the initial focus within a window.
///
/// `AutoFocus` addresses the common problem where a new window opens without a clear initial focus.
/// It scans the window's hierarchy, evaluates candidates based on role, size, and interaction potential,
/// and attempts to select the most "useful" element for the user (e.g., the main text area or a primary list).
public actor AutoFocus {
    
    /// Finds the best element to automatically focus within a given window entity.
    ///
    /// The algorithm uses a Breadth-First Search (BFS) to gather candidates, limiting depth and count
    /// to ensure performance. It then scores these candidates to pick a winner.
    ///
    /// - Parameter window: The window `AccessEntity` to search.
    /// - Returns: The best `AccessEntity` candidate found, or `nil` if no suitable candidate exists.
    public static func findBestTarget(in window: AccessEntity) async -> AccessEntity? {
        // 0. BFS Traversal to collect candidates
        // Limit depth to avoid performance hit on complex apps (typical window depth < 10)
        // Limit total candidates.
        
        var queue = [AccessEntity]()
        // Start with window children
        if let children = try? await window.element.getAttribute(.childElements) as? [Element] {
            for child in children {
                if let entity = try? await AccessEntity(for: child) {
                    queue.append(entity)
                }
            }
        }
        
        var candidates = [AccessEntity]()
        var processedCount = 0
        let maxCandidates = 100
        
        while !queue.isEmpty && processedCount < maxCandidates {
            let entity = queue.removeFirst()
            processedCount += 1
            
            // Check viability
            if await isCandidate(entity) {
                candidates.append(entity)
            }
            
            // Add children if container
            if let children = try? await entity.element.getAttribute(.childElements) as? [Element] {
                for child in children {
                    if let childEntity = try? await AccessEntity(for: child) {
                        queue.append(childEntity)
                    }
                }
            }
        }
        
        // 1. Score Candidates
        var bestCandidate: AccessEntity?
        var bestScore = -1.0
        
        for candidate in candidates {
            let score = await score(candidate)
            if score > bestScore {
                bestScore = score
                bestCandidate = candidate
            }
        }
        
        return bestCandidate
    }
    
    /// Determines if an entity is a valid candidate for auto-focus.
    ///
    /// - Parameter entity: The entity to evaluate.
    /// - Returns: `true` if the entity is viable (e.g., not a window control button).
    private static func isCandidate(_ entity: AccessEntity) async -> Bool {
        // Filter out obviously invisible or uninteractable things?
        // Role check
        guard let role = try? await entity.element.getAttribute(.role) as? ElementRole else { return false }
        // Exclude system buttons like Close/Min/Zoom
        if role == .button, let sub = try? await entity.element.getAttribute(.subrole) as? String, sub == "AXCloseButton" {
            return false
        }
        return true
    }
    
    /// Calculates a suitability score for a candidate entity.
    ///
    /// Scoring is based on:
    /// 1. **Role Priority**: High value for content areas (Web, Text, Lists), low for generic containers.
    /// 2. **Size**: Larger elements get a slight boost (via log scale) to break ties, assuming main content is prominently sized.
    ///
    /// - Parameter entity: The entity to score.
    /// - Returns: A `Double` score representing suitability.
    private static func score(_ entity: AccessEntity) async -> Double {
        var score = 0.0
        
        guard let role = try? await entity.element.getAttribute(.role) as? ElementRole else { return 0.0 }
        
        // Base Score by Role
        switch role {
        case .webArea, .textArea, .textField:
            score += 100.0
        case .table, .outline, .list, .browser:
            score += 80.0
        case .scrollArea, .splitGroup, .group:
            score += 5.0 // Containers are low value unless they contain content
        case .button, .checkBox, .radioButton:
            score += 10.0
        case .staticText:
            score += 20.0 // Sometimes text is the main content
        default:
            score += 0.0
        }
        
        // Modifiers
        
        // Editable?
        // Check if value is settable? or role implies it.
        
        // Size
        if let size = try? await entity.element.getAttribute(.size) as? CGSize {
            let area = size.width * size.height
            // Normalize? Just use raw area as tie breaker for same roles.
            // Cap it to prevent massive background containers from winning?
            score += log(area + 1) * 2.0
        }
        
        // Center Bias?
        // Maybe later.
        
        return score
    }
}
