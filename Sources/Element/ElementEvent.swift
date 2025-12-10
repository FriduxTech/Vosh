//
//  ElementEvent.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// A high-level representation of an accessibility event.
///
/// An `ElementEvent` captures a specific state change in the UI (e.g., focus change, value update)
/// reported by the Accessibility system. It bundles the type of notification, the element that source it,
/// and any optional context payload.
public struct ElementEvent {
    
    /// The type of notification triggered (e.g., `.focusedUIElementChanged`, `.valueChanged`).
    public let notification: ElementNotification
    
    /// The accessibility element that triggered the event.
    public let subject: Element
    
    /// A dictionary of additional information provided with the event (can be nil).
    public let payload: [PayloadKey: Any]?

    /// Initializes a new `ElementEvent` from raw values.
    ///
    /// - Parameters:
    ///   - notification: The string identifier of the notification. Returns nil if unknown.
    ///   - subject: The `Element` associated with the event.
    ///   - payload: A raw dictionary of payload data. keys are converted to typed `PayloadKey`s.
    init?(notification: String, subject: Element, payload: [String: Any]) {
        guard let notification = ElementNotification(rawValue: notification) else {
            return nil
        }
        let payload = payload.reduce([PayloadKey: Any]()) {(previous, value) in
            guard let key = PayloadKey(rawValue: value.key) else {
                return previous
            }
            var next = previous
            next[key] = value.value
            return previous
        }
        self.notification = notification
        self.subject = subject
        self.payload = payload
    }
}
