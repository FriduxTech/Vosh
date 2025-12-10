//
//  ElementObserver.swift
//  Vosh
//
//  Created by Vosh Team.
//

import ApplicationServices

/// Monitors an accessibility element (typically an Application) for global notifications.
///
/// `ElementObserver` wraps the `AXObserver` API, providing a modern Swift `AsyncStream`
/// interface for handling accessibility events. It handles the low-level details of
/// run loop registration and C-callback bridging.
@MainActor public final class ElementObserver {
    
    /// An asynchronous stream of events produced by the observed element.
    public let eventStream: AsyncStream<ElementEvent>
    
    /// The underlying Core Foundation observer reference.
    private let observer: AXObserver
    
    /// The raw `AXUIElement` being observed (usually the application).
    private let element: AXUIElement
    
    /// Internal continuation to yield events into the stream.
    private let eventContinuation: AsyncStream<ElementEvent>.Continuation

    /// Initializes a new observer for the specified accessibility element (application).
    ///
    /// The initialization involves:
    /// 1. Creating the underlying `AXObserver` for the target process.
    /// 2. Setting up a C-function callback that forwards events to this class instance.
    /// 3. Attaching the observer's run loop source to the Main Run Loop.
    ///
    /// - Parameter element: The application `Element` to observe.
    /// - Throws: `ElementError` if observer creation fails.
    public init(element: Element) async throws {
        self.element = element.legacyValue as! AXUIElement
        let processIdentifier = try element.getProcessIdentifier()
        var observer: AXObserver?
        
        // Define the C-style callback closure
        let callBack: AXObserverCallbackWithInfo = {(_, element, notification, info, this) in
            // Reconstruct the Swift instance from the opaque pointer
            let this = Unmanaged<ElementObserver>.fromOpaque(this!).takeUnretainedValue()
            let notification = notification as String
            
            // Wrap the subject element
            let subject = Element(legacyValue: element)!
            
            // Extract the user-info payload safely
            // Note: 'info' is technically CFDictionaryRef? but comes as UnsafeMutableRawPointer? in the signature
            // The following check determines validity.
            let payload = unsafeBitCast(info, to: Int.self) != 0 ? [String: Any](legacyValue: info) : nil
            
            // Construct and emit the event
            let event = ElementEvent(notification: notification, subject: subject, payload: payload ?? [:])!
            this.eventContinuation.yield(event)
        }
        
        // Create the observer with the callback
        let result = AXObserverCreateWithInfoCallback(processIdentifier, callBack, &observer)
        let error = ElementError(from: result)
        
        guard error == .success, let observer = observer else {
            switch error {
            case .apiDisabled, .notImplemented, .timeout:
                throw error
            default:
                fatalError("Unexpected error creating an accessibility element observer: \(error)")
            }
        }
        self.observer = observer
        
        // Initialize the event stream
        (eventStream, eventContinuation) = AsyncStream<ElementEvent>.makeStream()
        
        // Attach to the RunLoop (must be done on MainActor usually, or the thread where RunLoop runs)
        // Here we assume the observer needs to run on the main run loop to catch system events effectively.
        await MainActor.run() {
            let runLoopSource = AXObserverGetRunLoopSource(observer)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        }
    }

    /// Registers for a specific notification type.
    ///
    /// Once subscribed, the application will send events for this notification type
    /// to the `eventStream`.
    ///
    /// - Parameter notification: The `ElementNotification` to observe.
    /// - Throws: `ElementError` if registration fails (e.g. not supported by app).
    public func subscribe(to notification: ElementNotification) throws {
        let result = AXObserverAddNotification(observer, element, notification.rawValue as CFString, Unmanaged.passUnretained(self).toOpaque())
        let error = ElementError(from: result)
        switch error {
        case .success, .notificationAlreadyRegistered:
            break
        case .apiDisabled, .invalidElement, .notificationUnsupported, .timeout:
            throw error
        default:
            fatalError("Unexpected error registering accessibility element notification \(notification.rawValue): \(error)")
        }
    }

    /// Unregisters from a specific notification type.
    ///
    /// - Parameter notification: The `ElementNotification` to stop observing.
    /// - Throws: `ElementError` if unregistration fails.
    public func unsubscribe(from notification: ElementNotification) throws {
        let result = AXObserverRemoveNotification(observer, element, notification.rawValue as CFString)
        let error = ElementError(from: result)
        switch error {
        case .success, .notificationNotRegistered:
            break
        case .apiDisabled, .invalidElement, .notificationUnsupported, .timeout:
            throw error
        default:
            fatalError("Unexpected error unregistering accessibility element notification \(notification.rawValue): \(error)")
        }
    }

    /// Explicitly invalidates the observer, removing it from the run loop.
    private var isInvalidated = false
    public func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        eventContinuation.finish()
        
        let observer = self.observer
        // Remove from RunLoop on MainActor
        Task { @MainActor in
            let runLoopSource = AXObserverGetRunLoopSource(observer)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
    }

    /// Cleanup when the observer is deallocated.
    /// Cleanup when the observer is deallocated.
    deinit {
        if !isInvalidated {
             // CRITICAL: Accessing the run loop source after deallocation is a crash risk.
             // We MUST have invalidated before this point.
             // fatalError("ElementObserver must be invalidated before deinit to prevent run loop crashes.")
             print("Error: ElementObserver deallocated without invalidation. This may cause a crash.")
        }
    }
}
