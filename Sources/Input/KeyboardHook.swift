//
//  KeyboardHook.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import CoreGraphics
import Foundation

/// Manages the low-level CoreGraphics Event Tap for intercepting keyboard input.
/// N.B. This class is thread-safe and can be used on any thread, but usually invoked from MainActor.
final class KeyboardHook {
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    /// The callback applied to each intercepted event. 
    /// Returns the event to pass through, or nil to swallow it.
    private var onEvent: ((CGEvent) -> CGEvent?)?
    
    private let lock = NSLock()
    
    init() {}
    
    /// Starts the event tap.
    /// - Parameter handler: A closure that processes the event and returns it (pass-through) or nil (swallow).
    ///                      The closure is called synchronously on the run loop thread (Main).
    func start(handler: @escaping (CGEvent) -> CGEvent?) {
        lock.lock()
        defer { lock.unlock() }
        
        self.onEvent = handler
        
        // Define C-compatible callback that bridges to the Swift instance
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            // Handle timeout
            if type == .tapDisabledByTimeout {
                if let refcon = refcon {
                    let this = Unmanaged<KeyboardHook>.fromOpaque(refcon).takeUnretainedValue()
                    this.reenableTap()
                }
                return nil
            }
            // type == .tapDisabledByUserInput?
            
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let this = Unmanaged<KeyboardHook>.fromOpaque(refcon).takeUnretainedValue()
            
            if let result = this.handleEvent(event) {
                return Unmanaged.passUnretained(result)
            }
            return nil
        }
        
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap,
                                          place: .tailAppendEventTap,
                                          options: .defaultTap,
                                          eventsOfInterest: 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue | 1 << CGEventType.flagsChanged.rawValue,
                                          callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            // Graceful failure (logged by caller checking specific behavior, here we just return or log)
            print("Vosh: Failed to create keyboard event tap")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.defaultMode)
    }
    
    // Internal helper to handle event with lock safety if needed, though callback runs on Main Loop serial.
    // However, handler might touch MainActor state?
    // Input passes `handleEventTap` which is @MainActor.
    // If callback runs on Main Thread, it is on MainActor executor effectively?
    // Swift 6 might complain if we call @MainActor func from non-isolated context (callback).
    // Start saves `onEvent`. `onEvent` captures `Input.handleEventTap`.
    // We call `this.onEvent?(event)`.
    
    private func handleEvent(_ event: CGEvent) -> CGEvent? {
        // We assume this runs on Main Thread given we attached to CFRunLoopGetMain().
        // If strict concurrency checks fail here, we might need unsafe assumptions or MainActor.assumeIsolated.
        return onEvent?(event)
    }
    
    private func reenableTap() {
        lock.lock()
        defer { lock.unlock() }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.defaultMode)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }
    
    deinit {
        stop()
    }
}
