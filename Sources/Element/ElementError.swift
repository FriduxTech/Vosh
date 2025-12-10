//
//  ElementError.swift
//  Vosh
//
//  Created by Vosh Team.
//

import ApplicationServices

/// A comprehensive Swift wrapper for the legacy `AXError` C-enumeration.
///
/// This type bridges core accessibility errors into the Swift `Error` protocol,
/// enabling idomatic do-catch error handling and better debugging descriptions.
public enum ElementError: Error, CustomStringConvertible {
    
    /// The operation completed successfully.
    case success
    
    /// A generic system failure occurred.
    case systemFailure
    
    /// An illegal argument was passed to the function.
    case illegalArgument
    
    /// The `AXUIElement` is invalid (e.g., the application died or the element was destroyed).
    case invalidElement
    
    /// The `AXObserver` is invalid.
    case invalidObserver
    
    /// The operation timed out (app busy or not responding).
    case timeout
    
    /// The requested attribute is not supported by the element.
    case attributeUnsupported
    
    /// The requested action is not supported by the element.
    case actionUnsupported
    
    /// The requested notification is not supported.
    case notificationUnsupported
    
    /// The application does not implement accessibility support for this request.
    case notImplemented
    
    /// The observer is already registered for this notification.
    case notificationAlreadyRegistered
    
    /// The observer is not registered for this notification.
    case notificationNotRegistered
    
    /// The Accessibility API is disabled (User needs to grant permissions).
    case apiDisabled
    
    /// The attribute exists but has no value.
    case noValue
    
    /// The parameterized attribute is not supported.
    case parameterizedAttributeUnsupported
    
    /// The available precision is insufficient for the request.
    case notEnoughPrecision

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .success:
            return "Success"
        case .systemFailure:
            return "System failure"
        case .illegalArgument:
            return "Illegal argument"
        case .invalidElement:
            return "Invalid element"
        case .invalidObserver:
            return "Invalid observer"
        case .timeout:
            return "Request timed out"
        case .attributeUnsupported:
            return "Attribute unsupported"
        case .actionUnsupported:
            return "Action unsupported"
        case .notificationUnsupported:
            return "Notification unsupported"
        case .parameterizedAttributeUnsupported:
            return "Parameterized attribute unsupported"
        case .notImplemented:
            return "Accessibility not supported"
        case .notificationAlreadyRegistered:
            return "Notification already registered"
        case .notificationNotRegistered:
            return "Notification not registered"
        case .apiDisabled:
            return "Accessibility API disabled"
        case .noValue:
            return "No value"
        case .notEnoughPrecision:
            return "Not enough precision"
        }
    }

    /// Initializes a Swift `ElementError` from a legacy `AXError` code.
    ///
    /// - Parameter error: The raw `AXError` value.
    init(from error: AXError) {
        switch error {
        case .success:
            self = .success
        case .failure:
            self = .systemFailure
        case .illegalArgument:
            self = .illegalArgument
        case .invalidUIElement:
            self = .invalidElement
        case .invalidUIElementObserver:
            self = .invalidObserver
        case .cannotComplete:
            self = .timeout
        case .attributeUnsupported:
            self = .attributeUnsupported
        case .actionUnsupported:
            self = .actionUnsupported
        case .notificationUnsupported:
            self = .notificationUnsupported
        case .parameterizedAttributeUnsupported:
            self = .parameterizedAttributeUnsupported
        case .notImplemented:
            self = .notImplemented
        case .notificationAlreadyRegistered:
            self = .notificationAlreadyRegistered
        case .notificationNotRegistered:
            self = .notificationNotRegistered
        case .apiDisabled:
            self = .apiDisabled
        case .noValue:
            self = .noValue
        case .notEnoughPrecision:
            self = .notEnoughPrecision
        @unknown default:
            fatalError("Unrecognized AXError case")
        }
    }

    /// Converts back to a legacy `AXError` code.
    ///
    /// Useful when validting or passing errors back to C-APIs.
    ///
    /// - Returns: The corresponding `AXError` value.
    func toAXError() -> AXError {
        switch self {
        case .success:
            return .success
        case .systemFailure:
            return .failure
        case .illegalArgument:
            return .illegalArgument
        case .invalidElement:
            return .invalidUIElement
        case .invalidObserver:
            return .invalidUIElementObserver
        case .timeout:
            return .cannotComplete
        case .attributeUnsupported:
            return .attributeUnsupported
        case .actionUnsupported:
            return .actionUnsupported
        case .notificationUnsupported:
            return .notificationUnsupported
        case .parameterizedAttributeUnsupported:
            return .parameterizedAttributeUnsupported
        case .notImplemented:
            return .notImplemented
        case .notificationAlreadyRegistered:
            return .notificationAlreadyRegistered
        case .notificationNotRegistered:
            return .notificationNotRegistered
        case .apiDisabled:
            return .apiDisabled
        case .noValue:
            return .noValue
        case .notEnoughPrecision:
            return .notEnoughPrecision
        }
    }
}
