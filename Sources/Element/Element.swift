//
//  Element.swift
//  Vosh
//
//  Created by Vosh Team.
//

import ApplicationServices

/// A type-safe, actor-isolated wrapper around the legacy Core Accessibility `AXUIElement` API.
///
/// `Element` is the foundational building block of the accessibility system. It represents
/// any accessible UI component (Application, Window, Button, etc.) and provides a
/// modern Swift interface for reading/writing attributes, performing actions, and
/// traversing the accessibility hierarchy.
public struct Element: @unchecked Sendable {
    
    /// The underlying Core Foundation reference to the accessibility object.
    nonisolated let legacyValue: CFTypeRef
    
    /// Retrieves the raw `AXUIElement` reference.
    ///
    /// - Returns: The underlying `AXUIElement`.
    public func getRawValue() -> AXUIElement { legacyValue as! AXUIElement }

    /// Initializes a new element representing the System Wide accessibility object.
    ///
    /// This element is the root of the accessibility tree and is used for global
    /// operations like hit-testing or locating the focused application.
    public init() {
        legacyValue = AXUIElementCreateSystemWide()
    }

    /// Initializes a new element representing a running application.
    ///
    /// - Parameter processIdentifier: The Process ID (PID) of the target application.
    public init(processIdentifier: pid_t) {
        legacyValue = AXUIElementCreateApplication(processIdentifier)
    }

    /// Initializes a new element by wrapping an existing `AXUIElement` reference.
    ///
    /// - Parameter value: The raw `AXUIElement` (as `CFTypeRef`) to wrap.
    ///   Returns `nil` if the provided value is not a valid `AXUIElement`.
    nonisolated init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        legacyValue = unsafeBitCast(value, to: AXUIElement.self)
    }

    /// Retrieves the Application element that owns this element.
    ///
    /// This is useful for climbing back up to the app root from any UI component.
    ///
    /// - Returns: The parent `Element` representing the application.
    /// - Throws: An error if the process ID cannot be determined.
    public func getApplication() async throws -> Element {
        let processIdentifier = try getProcessIdentifier()
        return Element(processIdentifier: processIdentifier)
    }

    /// Retrieves the Process ID (PID) associated with this element.
    ///
    /// - Returns: The `pid_t` of the owning process.
    /// - Throws: `ElementError` if the PID cannot be retrieved (e.g., element is invalid/expired).
    public func getProcessIdentifier() throws -> pid_t {
        let legacyValue = legacyValue as! AXUIElement
        var processIdentifier = pid_t(0)
        let result = AXUIElementGetPid(legacyValue, &processIdentifier)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error reading an accessibility element's process identifier: \(error)")
        }
        return processIdentifier
    }

    /// Sets the IPC timeout for accessibility requests made to this element.
    ///
    /// Useful for interacting with slow or unresponsive applications without blocking indefinitely.
    ///
    /// - Parameter seconds: The timeout duration in seconds.
    public func setTimeout(seconds: Float) async throws {
        let legacyValue = legacyValue as! AXUIElement
        let result = AXUIElementSetMessagingTimeout(legacyValue, seconds)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error setting an accessibility element's request timeout: \(error)")
        }
    }

    /// Serializes the element and its hierarchy into a dictionary structure.
    ///
    /// This is primarily used for debugging, logging, or inspecting the accessibility tree.
    ///
    /// - Parameters:
    ///   - recursiveParents: If `true`, climbs up the parent chain (limited recursion).
    ///   - recursiveChildren: If `true`, descends into children (limited recursion).
    /// - Returns: A dictionary representation of the element, or `nil` if invalid.
    public func dump(recursiveParents: Bool = true, recursiveChildren: Bool = true) async throws -> [String: Any]? {
        do {
            var root = [String: Any]()
            let attributes = try listAttributes()
            var attributeValues = [String: Any]()
            for attribute in attributes {
                guard let value = try getAttribute(attribute) else {
                    continue
                }
                attributeValues[attribute] = encode(value: value)
            }
            root["attributes"] = attributeValues
            guard legacyValue as! AXUIElement != AXUIElementCreateSystemWide() else {
                return root
            }
            let parameterizedAttributes = try listParameterizedAttributes()
            root["parameterizedAttributes"] = parameterizedAttributes
            root["actions"] = try await listActions()
            if recursiveParents, let parent = try getAttribute("AXParent") as? Element {
                root["parent"] = try await parent.dump(recursiveParents: true, recursiveChildren: false)
            }
            if recursiveChildren, let children = try getAttribute("AXChildren") as? [Any?] {
                var resultingChildren = [Any]()
                for child in children.lazy.compactMap({$0 as? Element}) {
                    guard let child = try await child.dump(recursiveParents: false, recursiveChildren: true) else {
                        continue
                    }
                    resultingChildren.append(child)
                }
                root["children"] = resultingChildren
            }
            return root
        } catch ElementError.invalidElement {
            return nil
        } catch {
            throw error
        }
    }

    /// Retrieves all supported standard attributes for this element.
    ///
    /// - Returns: A `Set` of `ElementAttribute` enums.
    public func getAttributeSet() async throws -> Set<ElementAttribute> {
        let attributes = try listAttributes()
        return Set(attributes.lazy.compactMap({ElementAttribute(rawValue: $0)}))
    }

    /// Retrieves the value of a specific attribute.
    ///
    /// Automatically handles type conversion for known types like Roles and Subroles.
    ///
    /// - Parameter attribute: The `ElementAttribute` to query.
    /// - Returns: The attribute value (type varies), or `nil` if not set.
    public func getAttribute(_ attribute: ElementAttribute) async throws -> Any? {
        let output = try getAttribute(attribute.rawValue)
        if attribute == .role, let output = output as? String {
            return ElementRole(rawValue: output)
        }
        if attribute == .subrole, let output = output as? String {
            return ElementSubrole(rawValue: output)
        }
        return output
    }

    /// Sets the value of a specific attribute.
    ///
    /// - Parameters:
    ///   - attribute: The `ElementAttribute` to set.
    ///   - value: The new value (must match the expected type for the attribute).
    public func setAttribute(_ attribute: ElementAttribute, value: Any) async throws {
        return try setAttribute(attribute.rawValue, value: value)
    }

    /// Retrieves all supported parameterized attributes for this element.
    ///
    /// Parameterized attributes require an input parameter to retrieve a value (e.g., bounds for a text range).
    ///
    /// - Returns: A `Set` of `ElementParameterizedAttribute` enums.
    public func getParameterizedAttributeSet() async throws -> Set<ElementParameterizedAttribute> {
        let attributes = try listParameterizedAttributes()
        return Set(attributes.lazy.compactMap({ElementParameterizedAttribute(rawValue: $0)}))
    }

    /// Queries a parameterized attribute.
    ///
    /// - Parameters:
    ///   - attribute: The `ElementParameterizedAttribute` to query.
    ///   - input: The input parameter (e.g., a `CFRange` or `CGPoint`).
    /// - Returns: The resulting value, or `nil`.
    public func queryParameterizedAttribute(_ attribute: ElementParameterizedAttribute, input: Any) async throws -> Any? {
        return try queryParameterizedAttribute(attribute.rawValue, input: input)
    }

    /// Retrieves the list of actions supported by this element.
    ///
    /// Actions represent user interactions like "Press", "Increment", or "ShowMenu".
    ///
    /// - Returns: An array of action names as Strings.
    public func listActions() async throws -> [String] {
        let legacyValue = legacyValue as! AXUIElement
        var actions: CFArray?
        let result = AXUIElementCopyActionNames(legacyValue, &actions)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .systemFailure, .illegalArgument:
            return []
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error reading an accessibility elenet's action names: \(error)")
        }
        guard let actions = [Any?](legacyValue: actions as CFTypeRef) else {
            return []
        }
        return actions.compactMap({$0 as? String})
    }

    /// Retrieves a localized, human-readable description of an action.
    ///
    /// - Parameter action: The action name.
    /// - Returns: The localized description, or `nil`.
    public func describeAction(_ action: String) async throws -> String? {
        let legacyValue = legacyValue as! AXUIElement
        var description: CFString?
        let result = AXUIElementCopyActionDescription(legacyValue, action as CFString, &description)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .actionUnsupported, .illegalArgument, .systemFailure:
            return nil
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error reading an accessibility element's description for action \(action)")
        }
        guard let description = description else {
            return nil
        }
        return description as String
    }

    /// Triggers an action on the element.
    ///
    /// - Parameter action: The action name to perform (e.g., "AXPress").
    public func performAction(_ action: String) async throws {
        let legacyValue = legacyValue as! AXUIElement
        let result = AXUIElementPerformAction(legacyValue, action as CFString)
        let error = ElementError(from: result)
        switch error {
        case .success, .systemFailure, .illegalArgument:
            break
        case .actionUnsupported, .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error performing accessibility element action \(action): \(error.localizedDescription)")
        }
    }

    /// Retrieves the list of all raw attribute names.
    private func listAttributes() throws -> [String] {
        let legacyValue = legacyValue as! AXUIElement
        var attributes: CFArray?
        let result = AXUIElementCopyAttributeNames(legacyValue, &attributes)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error reading an accessibility element's attribute names: \(error)")
        }
        guard let attributes = [Any?](legacyValue: attributes as CFTypeRef) else {
            return []
        }
        return attributes.compactMap({$0 as? String})
    }

    /// Retrieves the raw value for a specific attribute name.
    private func getAttribute(_ attribute: String) throws -> Any? {
        let legacyValue = legacyValue as! AXUIElement
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(legacyValue, attribute as CFString, &value)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .attributeUnsupported, .noValue, .systemFailure, .illegalArgument:
            return nil
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error getting value for accessibility element attribute \(attribute): \(error)")
        }
        guard let value = value else {
            return nil
        }
        return fromLegacy(value: value)
    }

    /// Sets the raw value for a specific attribute name.
    private func setAttribute(_ attribute: String, value: Any) throws {
        let legacyValue = legacyValue as! AXUIElement
        guard let value = value as? any ElementLegacy else {
            throw ElementError.illegalArgument
        }
        let result = AXUIElementSetAttributeValue(legacyValue, attribute as CFString, value.legacyValue as CFTypeRef)
        let error = ElementError(from: result)
        switch error {
        case .success, .systemFailure, .attributeUnsupported, .illegalArgument:
            break
        case .apiDisabled, .invalidElement, .notEnoughPrecision, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error setting accessibility element attribute \(attribute): \(error)")
        }
    }

    /// Retrieves the list of all raw parameterized attribute names.
    private func listParameterizedAttributes() throws -> [String] {
        let legacyValue = legacyValue as! AXUIElement
        var parameterizedAttributes: CFArray?
        let result = AXUIElementCopyParameterizedAttributeNames(legacyValue, &parameterizedAttributes)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .apiDisabled, .invalidElement, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unexpected error reading an accessibility element's parameterized attribute names: \(error)")
        }
        guard let parameterizedAttributes = [Any?](legacyValue: parameterizedAttributes as CFTypeRef) else {
            return []
        }
        return parameterizedAttributes.compactMap({$0 as? String})
    }

    /// Queries the raw value for a parameterized attribute.
    private func queryParameterizedAttribute(_ attribute: String, input: Any) throws -> Any? {
        let legacyValue = legacyValue as! AXUIElement
        guard let input = input as? any ElementLegacy else {
            throw ElementError.illegalArgument
        }
        var output: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(legacyValue, attribute as CFString, input.legacyValue as CFTypeRef, &output)
        let error = ElementError(from: result)
        switch error {
        case .success:
            break
        case .noValue, .parameterizedAttributeUnsupported, .systemFailure, .illegalArgument:
            return nil
        case .apiDisabled, .invalidElement, .notEnoughPrecision, .notImplemented, .timeout:
            throw error
        default:
            fatalError("Unrecognized error querying parameterized accessibility element attribute \(attribute): \(error)")
        }
        return fromLegacy(value: output)
    }

    /// Helper to encode diverse types into a plist-compatible format.
    private func encode(value: Any) -> Any? {
        switch value {
        case is Bool, is Int64, is Double, is String:
            return value
        case let array as [Any?]:
            var resultArray = [Any]()
            resultArray.reserveCapacity(array.count)
            for element in array {
                guard let element = element, let element = encode(value: element) else {
                    continue
                }
                resultArray.append(element)
            }
            return resultArray
        case let dictionary as [String: Any]:
            var resultDictionary = [String: Any]()
            resultDictionary.reserveCapacity(dictionary.count)
            for pair in dictionary {
                guard let value = encode(value: pair.value) else {
                    continue
                }
                resultDictionary[pair.key] = value
            }
            return resultDictionary
        case let url as URL:
            return url.absoluteString
        case let attributedString as AttributedString:
            return String(attributedString.characters)
        case let point as CGPoint:
            return ["x": point.x, "y": point.y]
        case let size as CGSize:
            return ["width": size.width, "height": size.height]
        case let rect as CGRect:
            return ["x": rect.origin.x, "y": rect.origin.y, "width": rect.size.width, "height": rect.size.height]
        case let element as Element:
            return String(describing: element.legacyValue)
        case let error as ElementError:
            return "Error: \(error.localizedDescription)"
        default:
            return nil
        }
    }

    /// Verifies if the current process is a trusted accessibility client.
    ///
    /// - Returns: `true` if the app has Accessibility permissions in System Settings.
    @MainActor public static func confirmProcessTrustedStatus() -> Bool {
        return AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }
    
    /// Performs a hit test to find the accessibility element at a screen point.
    ///
    /// - Parameters:
    ///   - x: The screen X coordinate (global coordinates).
    ///   - y: The screen Y coordinate (global coordinates).
    /// - Returns: The top-most `Element` at that point, or `nil` if none found.
    public func at(x: Float, y: Float) async throws -> Element? {
        let legacyValue = legacyValue as! AXUIElement
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(legacyValue, x, y, &element)
        if result == .success, let element = element {
            return Element(legacyValue: element)
        }
        return nil
    }
}

extension Element: Hashable {
    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(legacyValue as! AXUIElement)
    }

    public static nonisolated func ==(_ lhs: Element, _ rhs: Element) -> Bool {
        let lhs = lhs.legacyValue as! AXUIElement
        let rhs = rhs.legacyValue as! AXUIElement
        return lhs == rhs
    }
}
