//
//  NotificationManager.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation

/// Represents a high-level, semantic event within the Vosh application.
///
/// Unlike raw accessibility notifications (which are noisy and low-level),
/// `VoshEvent` represents a "cleaned" event that the rest of the application should care about.
public enum VoshEventType: String, Codable, Sendable {
    case focusChanged
    case titleChanged
    case valueChanged
    case selectedTextChanged
    case layoutChanged
    case announcement // Custom announcements
    case alert
}

public struct VoshEvent: Sendable {
    public let type: VoshEventType
    public let timestamp: TimeInterval
    public let data: [String: String]
    
    public init(type: VoshEventType, data: [String: String] = [:]) {
        self.type = type
        self.timestamp = Date().timeIntervalSince1970
        self.data = data
    }
}

/// A centralized actor for managing and dispatching semantic application events.
///
/// `NotificationManager` serves as the event bus for Vosh, allowing different components
/// (e.g., Access, Braille, Output) to subscribe to a unified stream of events.
@globalActor public actor NotificationManager {
    
    public static let shared = NotificationManager()
    
    /// The stream of semantic events.
    public let events: AsyncStream<VoshEvent>
    
    private let continuation: AsyncStream<VoshEvent>.Continuation
    
    private init() {
        var continuation: AsyncStream<VoshEvent>.Continuation!
        self.events = AsyncStream { cont in
            continuation = cont
        }
        self.continuation = continuation
    }
    
    /// Publishes a new event to the stream.
    /// - Parameter event: The event to publish.
    public func publish(_ event: VoshEvent) {
        continuation.yield(event)
    }
    
    /// Convenience method to publish an event by type.
    public func publish(type: VoshEventType, data: [String: String] = [:]) {
        let event = VoshEvent(type: type, data: data)
        continuation.yield(event)
    }
}
