//
//  AccessWeb.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import Element
import Output

/// Manages "Browse Mode" (Linear Navigation) for web content.
///
/// `AccessWeb` flattens the hierarchical structure of a web page into a linear buffer,
/// allowing the user to navigate sequentially (next/previous) or by specific element types
/// (headings, links, form fields) similar to traditional screen readers.
@AccessActor final class AccessWeb {
    
    /// The root web area element.
    private let root: Element
    
    /// The current element in the virtual linear navigation.
    private var currentElement: Element
    
    /// Cache of the last fetched siblings to optimize list traversal O(N) -> O(1).
    /// Stores: (Parent Element, List of Child Elements)
    private var siblingsCache: (parent: Element, children: [Element])?
    
    /// Invalidates the sibling cache, forcing a re-fetch of the DOM tree on next navigation.
    func invalidateCache() {
        siblingsCache = nil
    }
    
    /// Resets navigation to the root element.
    func reset() {
        currentElement = root
    }
    
    /// Initializes a web accessor for a specific web area.
    ///
    /// - Parameter root: The root element of the web content.
    init(root: Element) {
        self.root = root
        self.currentElement = root
    }
    
    // MARK: - Navigation
    
    /// Moves focus to the next item in the DOM tree (Depth-First Pre-Order Traversal).
    ///
    /// - Returns: The next `Element`, or `nil` if at the end.
    func next() async -> Element? {
        // Recovery: Check if element is still valid
        do {
            _ = try await currentElement.getAttribute(.role)
        } catch {
             currentElement = root
             return root
        }
        
        // Algorithm:
        // 1. Try First Child
        // 2. Try Next Sibling
        // 3. Traverse up parents until a Next Sibling is found
        
        // 1. Child
        if let child = await getFirstChild(of: currentElement) {
            currentElement = child
            return child
        }
        
        // 2. Sibling or Parent's Sibling
        var pivot: Element? = currentElement
        var safetyCounter = 0
        while let p = pivot {
            safetyCounter += 1
            if safetyCounter > 50 { break } // Sanity check against cycles
            
            // FIX: Strict boundary check
            // If p is the root (WebArea), we do NOT want its sibling.
            if p == root { break } 
            
            if let sibling = await getNextSibling(of: p) {
                currentElement = sibling
                return sibling
            }
            pivot = await getParent(of: p)
            if pivot == root { break }
        }
        
        return nil
    }
    
    /// Moves focus to the previous item in the DOM tree.
    ///
    /// - Returns: The previous `Element`, or `nil` if at the start.
    func previous() async -> Element? {
        // Algorithm:
        // 1. Get Previous Sibling
        // 2. If Sibling exists, drill down to its last descendant (Last Child of Last Child...)
        // 3. If no Sibling, return Parent
        
        if let sibling = await getPreviousSibling(of: currentElement) {
            // Drill down to last deepest descendant
            var candidate = sibling
            while let lastChild = await getLastChild(of: candidate) {
                candidate = lastChild
            }
            currentElement = candidate
            return candidate
        }
        
        if let parent = await getParent(of: currentElement), parent != root {
            currentElement = parent
            return parent
        }
        
        return nil
    }
    
    /// Jumps forward to the next element confirming to a predicate.
    func nextElement(where predicate: (Element) async -> Bool) async -> Element? {
        while let next = await next() {
            if await predicate(next) {
                return next
            }
        }
        // Restore if not found? Or stay at end?
        // Standard behavior: stay at end or wrap. Let's stay at end or restore.
        // For now, let's restore to start to be safe if we want 'find' semantics,
        // but for 'navigation' usually we stay.
        // Actually simplest is just stop.
        return nil
    }
    
    /// Jumps backward to the previous element confirming to a predicate.
    func previousElement(where predicate: (Element) async -> Bool) async -> Element? {
        while let prev = await previous() {
            if await predicate(prev) {
                return prev
            }
        }
        return nil
    }
    
    // MARK: - Role Navigation Helpers
    
    func nextElement(role: ElementRole) async -> Element? {
        return await nextElement { el in
            return (try? await el.getAttribute(.role) as? ElementRole) == role
        }
    }
    
    func previousElement(role: ElementRole) async -> Element? {
        return await previousElement { el in
            return (try? await el.getAttribute(.role) as? ElementRole) == role
        }
    }
    
    // MARK: - Search
    
    func find(text: String, backwards: Bool = false) async -> Element? {
        // We scan from current position
        let predicate: (Element) async -> Bool = { el in
            if let t = try? await el.getAttribute(.title) as? String, t.localizedCaseInsensitiveContains(text) { return true }
            if let d = try? await el.getAttribute(.description) as? String, d.localizedCaseInsensitiveContains(text) { return true }
            if let v = try? await el.getAttribute(.value) as? String, v.localizedCaseInsensitiveContains(text) { return true }
            return false
        }
        
        // 1. Save current position
        let startPosition = currentElement
        
        // 2. Search from current
        if let found = backwards ? await previousElement(where: predicate) : await nextElement(where: predicate) {
            return found
        }
        
        // 3. Wrap Around
        // Move to opposite end
        currentElement = root
        
        if !backwards {
            await Output.shared.announce("Wrapping search")
            if let found = await nextElement(where: predicate) {
                return found
            }
        } else {
            // For backwards wrap, we'd need to go to end. Simplified: fail or just restart from root?
            // Root is start. Backwards from root returns nil immediately.
            // Efficient backwards wrap needs 'moveToEnd'.
            await Output.shared.announce("Not found")
        }
        
        // 4. Restore if absolutely nothing found
        currentElement = startPosition
        return nil
    }
    
    func findAll(role: ElementRole) async -> [Element] {
        // Warning: This effectively does a full scan (slow!)
        // Should be used with caution or limited scope.
        // For now, we implement a limited scan or just warn?
        // Let's scan from *current* to end? Or Root?
        // The original requirement was global find.
        // We'll scan from ROOT.
        var results: [Element] = []
        // Save state
        let saved = currentElement
        currentElement = root
        
        while let next = await next() {
            if (try? await next.getAttribute(.role) as? ElementRole) == role {
                results.append(next)
            }
        }
        
        // Restore
        currentElement = saved
        return results
    }
    
    // MARK: - Reading
    
    /// Reads continuously from the current cursor position.
    ///
    /// - Returns: An async stream of strings to speak.
    func readFromCursor() -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                while let next = await next() {
                    if Task.isCancelled { break }
                    
                    // Fallback: Ensure element is visible (Say All Scroll)
                    _ = try? await next.performAction("AXScrollToVisible")
                    try? await next.setAttribute(.isFocused, value: true)
                    
                    // Get text content
                    var text = ""
                    if let t = try? await next.getAttribute(.title) as? String { text = t }
                    else if let v = try? await next.getAttribute(.value) as? String { text = v }
                    else if let d = try? await next.getAttribute(.description) as? String { text = d }
                    
                    if !text.isEmpty {
                        continuation.yield(text)
                    }
                }
                continuation.finish()
                // Cursor remains at the end (or where user stopped)
            }
        }
    }

    
    // MARK: - Tree Helpers (AX API Wrappers)
    
    private func getFirstChild(of element: Element) async -> Element? {
        guard let children = try? await element.getAttribute(.childElements) as? [Element] else { return nil }
        // Optimization: Don't fetch all if we can get count? AX API usually fetches array.
        // Is isInteresting check needed here?
        // Live Walker usually visits everything and lets logic filter?
        // Or do we skip uninteresting nodes?
        // If we skip uninteresting nodes deeply, we might recurse.
        // Let's do raw traversal first, logic in next() loop?
        // No, next() is just finding the node.
        // We should skip "uninteresting" (layout) nodes automatically to act like a buffer.
        
        for child in children {
            if await isInteresting(child) { return child }
            // If child is NOT interesting (e.g. a Group), we must drill into IT immediately
            // effectively flattening the tree.
            if let grandChild = await getFirstChild(of: child) {
                 return grandChild
            }
        }
        return nil
    }
    
    private func getNextSibling(of element: Element) async -> Element? {
        guard let parent = try? await element.getAttribute(.parentElement) as? Element else { return nil }
        
        let children: [Element]
        if let cache = siblingsCache, cache.parent == parent {
            children = cache.children
        } else {
             guard let fetched = try? await parent.getAttribute(.childElements) as? [Element] else { return nil }
             children = fetched
             siblingsCache = (parent, children)
        }
        
        if let index = children.firstIndex(of: element), index + 1 < children.count {
            let sibling = children[index + 1]
            if await isInteresting(sibling) { return sibling }
            // If uninteresting, drill down
            if let child = await getFirstChild(of: sibling) { return child }
            return await getNextSibling(of: sibling)
        }
        return nil
    }
    
    private func getPreviousSibling(of element: Element) async -> Element? {
        guard let parent = try? await element.getAttribute(.parentElement) as? Element else { return nil }
        
        let children: [Element]
        if let cache = siblingsCache, cache.parent == parent {
            children = cache.children
        } else {
             guard let fetched = try? await parent.getAttribute(.childElements) as? [Element] else { return nil }
             children = fetched
             siblingsCache = (parent, children)
        }
        
        if let index = children.firstIndex(of: element), index > 0 {
             let sibling = children[index - 1]
             if await isInteresting(sibling) { return sibling }
             // If uninteresting?
             // If we move back to a group, we want its LAST child.
             // But here we are just finding the sibling node itself.
             return sibling // Caller handles drilling down to last child if needed?
             // Actually if sibling is uninteresting group, we want its contents.
        }
        return nil
    }
    
    private func getParent(of element: Element) async -> Element? {
        return try? await element.getAttribute(.parentElement) as? Element
    }
    
    private func getLastChild(of element: Element) async -> Element? {
        guard let children = try? await element.getAttribute(.childElements) as? [Element], !children.isEmpty else { return nil }
        return children.last
    }

    private func isInteresting(_ element: Element) async -> Bool {
        guard let role = try? await element.getAttribute(.role) as? ElementRole else { return false }
        switch role {
        case .group, .webArea, .unknown:
            if let title = try? await element.getAttribute(.title) as? String, !title.isEmpty { return true }
            if let desc = try? await element.getAttribute(.description) as? String, !desc.isEmpty { return true }
            return false
        default:
            return true
        }
    }
}
