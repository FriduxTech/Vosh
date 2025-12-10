//
//  AccessEntity.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Element

/// A comprehensive wrapper around an `Element` that provides high-level accessibility navigation and logic.
///
/// `AccessEntity` abstracts the raw accessibility element to support intelligent navigation (finding "interesting" nodes),
/// focus management, and hierarchy traversal rules (e.g., distinguishing between leaf nodes and containers).
@AccessActor public final class AccessEntity {
    
    /// The underlying system accessibility element.
    public let element: Element

    /// Initializes a new access entity for the given element.
    ///
    /// - Parameter element: The raw `Element` to wrap.
    public init(for element: Element) async throws {
        self.element = element
    }

    /// Finds the nearest "interesting" parent of this entity.
    ///
    /// An "interesting" parent is one that conveys meaningful information to the user,
    /// skipping over irrelevant containers or structural nodes.
    ///
    /// - Returns: The parent `AccessEntity`, or `nil` if no suitable parent exists.
    public func getParent() async throws -> AccessEntity? {
        guard let parent = try await Self.findParent(of: element, depth: 0) else {
            return nil
        }
        return try await AccessEntity(for: parent)
    }

    /// Finds the first "interesting" child of this entity.
    ///
    /// This is used to "enter" a container or group.
    ///
    /// - Returns: The first interesting child `AccessEntity`, or `nil` if none are found.
    public func getFirstChild() async throws -> AccessEntity? {
        guard let child = try await Self.findFirstChild(of: element, backwards: false, depth: 0) else {
            return nil
        }
        return try await AccessEntity(for: child)
    }

    /// Finds the next or previous "interesting" sibling of this entity.
    ///
    /// This method traverses the accessibility hierarchy to find the next logical element
    /// for navigation, potentially jumping out of the current container if necessary.
    ///
    /// - Parameter backwards: If `true`, searches for the previous sibling.
    /// - Returns: The sibling `AccessEntity`, or `nil` if no more siblings exist.
    public func getNextSibling(backwards: Bool) async throws -> AccessEntity? {
        guard let element = try await Self.findNextSibling(of: element, backwards: backwards, depth: 0) else {
            return nil
        }
        return try await AccessEntity(for: element)
    }

    /// Attempts to set the system keyboard focus to this element.
    ///
    /// This method handles various element roles and focus strategies, including ensuring
    /// that focusable ancestors are correctly handled if the element itself cannot accept focus directly.
    public func setKeyboardFocus() async throws {
        do {
            try await element.setAttribute(.isFocused, value: true)
            guard let role = try await element.getAttribute(.role) as? ElementRole else {
                return
            }
            // Some roles don't need additional checks or focus ancestor logic? 
            // Or this switch is intended to filter roles that *should* be focused directly?
            switch role {
            case .button, .checkBox, .colorWell, .comboBox,
                    .dateField, .incrementer, .link, .menuBarItem,
                    .menuButton, .menuItem, .popUpButton, .radioButton,
                    .slider, .textArea, .textField, .timeField:
                break
            default:
                return
            }
            if let isFocused = try await element.getAttribute(.isFocused) as? Bool, isFocused {
                return
            }
            // Fallback: Try focusing the focusable ancestor
            if let focusableAncestor = try await element.getAttribute(.focusableAncestor) as? Element {
                try await focusableAncestor.setAttribute(.isFocused, value: true)
            }
        } catch ElementError.attributeUnsupported {
            return
        } catch {
            throw error
        }
    }

    /// Checks if this entity belongs to the focus group of another entity.
    ///
    /// This is used to determine if two elements are effectively part of the same interactive control
    /// (e.g., parts of the same composite widget).
    ///
    /// - Parameter entity: The potential child entity to check.
    /// - Returns: `true` if `entity` is in the focus group of this entity.
    public func isInFocusGroup(of entity: AccessEntity) async throws -> Bool {
        guard let element = try await element.getAttribute(.focusableAncestor) as? Element else {
            return false
        }
        return element == entity.element
    }

    /// Recursive helper to find an interesting parent.
    private static func findParent(of element: Element, depth: Int) async throws -> Element? {
        if depth > 20 { return nil }
        guard let parent = try await element.getAttribute(.parentElement) as? Element, try await !isRoot(element: parent) else {
            return nil
        }
        guard try await isInteresting(element: parent) else {
            return try await findParent(of: parent, depth: depth + 1)
        }
        return parent
    }

    /// Recursive helper to find the next interesting sibling.
    ///
    /// - Parameters:
    ///   - element: The starting element.
    ///   - backwards: Direction of search.
    ///   - depth: Current recursion depth.
    /// - Returns: The next interesting sibling element.
    private static func findNextSibling(of element: Element, backwards: Bool, depth: Int) async throws -> Element? {
        if depth > 20 { return nil }
        guard let parent = try await element.getAttribute(.parentElement) as? Element else {
            return nil
        }
        let siblings: [Element]? = if let siblings = try await parent.getAttribute(.childElementsInNavigationOrder) as? [Any?] {
            siblings.compactMap({$0 as? Element})
        } else if let siblings = try await element.getAttribute(.childElements) as? [Any?] {
            siblings.compactMap({$0 as? Element})
        } else {
            nil
        }
        guard let siblings = siblings, !siblings.isEmpty else {
            return nil
        }
        var orderedSiblings = siblings
        if backwards {
            orderedSiblings.reverse()
        }
        for sibling in orderedSiblings.drop(while: {$0 != element}).dropFirst() {
            if try await isInteresting(element: sibling) {
                return sibling
            }
            if let child = try await findFirstChild(of: sibling, backwards: backwards, depth: depth + 1) {
                return child
            }
        }
        guard try await !isRoot(element: parent), try await !isInteresting(element: parent) else {
            return nil
        }
        return try await findNextSibling(of: parent, backwards: backwards, depth: depth + 1)
    }

    /// Recursive helper to find the first interesting child.
    ///
    /// - Parameters:
    ///   - element: The parent element.
    ///   - backwards: Direction (rarely used for first child logic but supported).
    ///   - depth: Current recursion depth.
    /// - Returns: The first interesting child element.
    private static func findFirstChild(of element: Element, backwards: Bool, depth: Int) async throws -> Element? {
        if depth > 20 { return nil }
        if try await isLeaf(element: element) {
            return nil
        }
        let children: [Element]? = if let children = try await element.getAttribute(.childElementsInNavigationOrder) as? [Any?] {
            children.compactMap({$0 as? Element})
        } else if let children = try await element.getAttribute(.childElements) as? [Any?] {
            children.compactMap({$0 as? Element})
        } else {
            nil
        }
        guard let children = children, !children.isEmpty else {
            return nil
        }
        var orderedChildren = children
        if backwards {
            orderedChildren.reverse()
        }
        for child in orderedChildren {
            if try await isInteresting(element: child) {
                return child
            }
            if try await isLeaf(element: child) {
                return nil
            }
            if let child = try await findFirstChild(of: child, backwards: backwards, depth: depth + 1) {
                return child
            }
        }
        return nil
    }

    /// Determines if an element is "interesting" for accessibility purposes.
    ///
    /// An element is interesting if it is focusable, has a title or description,
    /// or has a specific role that implies interaction or content.
    ///
    /// - Parameter element: The element to evaluate.
    /// - Returns: `true` if the element should be exposed to the user.
    private static func isInteresting(element: Element) async throws -> Bool {
        if let isFocused = try await element.getAttribute(.isFocused) as? Bool, isFocused {
            return true
        }
        if let title = try await element.getAttribute(.title) as? String, !title.isEmpty {
            return true
        }
        if let description = try await element.getAttribute(.description) as? String, !description.isEmpty {
            return true
        }
        guard let role = try await element.getAttribute(.role) as? ElementRole else {
            return false
        }
        switch role {
        case .browser, .busyIndicator, .button, .cell,
                .checkBox, .colorWell, .comboBox, .dateField,
                .disclosureTriangle, .dockItem, .drawer, .grid,
                .growArea, .handle, .heading, .image,
                .levelIndicator, .link, .list, .menuBarItem,
                .menuItem, .menuButton, .outline, .popUpButton, .popover,
                .progressIndicator, .radioButton, .relevanceIndicator, .sheet,
                .slider, .staticText, .tabGroup, .table,
                .textArea, .textField, .timeField, .toolbar,
                .valueIndicator, .webArea:
            let isLeaf = try await isLeaf(element: element)
            let hasWebAncestor = try await hasWebAncestor(element: element)
            return !hasWebAncestor || hasWebAncestor && isLeaf
        default:
            return false
        }
    }

    /// Determines if an element acts as a navigation root (e.g., a Window or Menu Bar).
    ///
    /// Copied from standard practices, roots usually stop parent traversal.
    ///
    /// - Parameter element: The element to check.
    /// - Returns: `true` if the element is a root.
    private static func isRoot(element: Element) async throws -> Bool {
        guard let role = try await element.getAttribute(.role) as? ElementRole else {
            return false
        }
        switch role {
        case .menu, .menuBar, .window:
            return true
        default:
            return false
        }
    }

    /// Determines if an element should be treated as a leaf node (no children).
    ///
    /// Even if the element strictly has children in the accessibility tree (e.g. static text inside a button),
    /// we often treat controls like buttons as leaves for navigation simplicity.
    ///
    /// - Parameter element: The element to check.
    /// - Returns: `true` if the element is a leaf.
    private static func isLeaf(element: Element) async throws -> Bool {
        guard let role = try await element.getAttribute(.role) as? ElementRole else {
            return false
        }
        switch role {
        case .busyIndicator, .button, .checkBox, .colorWell,
                .comboBox, .dateField, .disclosureTriangle, .dockItem,
                .heading, .image, .incrementer, .levelIndicator,
                .link, .menuBarItem, .menuButton, .menuItem,
                .popUpButton, .progressIndicator, .radioButton, .relevanceIndicator,
                .scrollBar, .slider, .staticText, .textArea,
                .textField, .timeField, .valueIndicator:
            return true
        default:
            return false
        }
    }

    /// Recursively checks if an element is part of a web content area.
    ///
    /// - Parameter element: The element to check.
    /// - Returns: `true` if any ancestor has the `.webArea` role.
    static func hasWebAncestor(element: Element) async throws -> Bool {
        guard let parent = try await element.getAttribute(.parentElement) as? Element else {
            return false
        }
        guard let role = try await parent.getAttribute(.role) as? ElementRole else {
            return false
        }
        if role == .webArea {
            return true
        }
        return try await hasWebAncestor(element: parent)
    }
}
