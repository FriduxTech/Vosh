//
//  MultitouchManager.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import Output

/// Manages low-level multi-touch interaction via the private `MultitouchSupport` framework.
///
/// `MultitouchManager` directly accesses private macOS APIs to get raw finger contact data from the trackpad.
/// This allows for sophisticated gesture recognition (like multi-finger taps and precise coordinate tracking)
/// that `NSEvent` does not expose natively for background applications.
///
/// - Warning: This utilizes private APIs (`MultitouchSupport.framework`) via `dlopen`/`dlsym`. It may break
/// in future macOS versions and is not safe for Mac App Store submission.
@MainActor
public final class MultitouchManager {
    
    /// Shared singleton instance.
    public static let shared = MultitouchManager()
    
    // MARK: - Type Definitions
    
    // Opaque types representing internal MultitouchSupport structures.
    typealias MTDeviceRef = OpaquePointer
    typealias MTContactRef = OpaquePointer
    
    // MARK: - Function Pointers
    
    // C-Function signatures for dynamic linking.
    private var MTDeviceCreateList: (@convention(c) () -> CFArray)?
    private var MTRegisterContactFrameCallback: (@convention(c) (MTDeviceRef, @convention(c) (MTDeviceRef, Int32, Int32, UnsafeMutableRawPointer, Int32, Double, Int32) -> Void) -> Void)?
    private var MTDeviceStart: (@convention(c) (MTDeviceRef, Int32) -> Void)?
    private var MTDeviceStop: (@convention(c) (MTDeviceRef, Int32) -> Void)?
    
    /// Retained list of active trackpad devices to prevent deallocation.
    private var activeDevices: [AnyObject] = []
    
    /// Internal flag tracking the active state.
    private var isRunning = false
    
    /// Private initializer loading the framework symbols.
    private init() {
        loadFramework()
    }
    
    /// Dynamically loads the `MultitouchSupport.framework` and resolves required symbols.
    private func loadFramework() {
        let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY)
        guard handle != nil else {
            print("Failed to load MultitouchSupport")
            return
        }
        
        if let sym = dlsym(handle, "MTDeviceCreateList") {
            MTDeviceCreateList = unsafeBitCast(sym, to: (@convention(c) () -> CFArray).self)
        }
        if let sym = dlsym(handle, "MTRegisterContactFrameCallback") {
            MTRegisterContactFrameCallback = unsafeBitCast(sym, to: (@convention(c) (MTDeviceRef, @convention(c) (MTDeviceRef, Int32, Int32, UnsafeMutableRawPointer, Int32, Double, Int32) -> Void) -> Void).self)
        }
        if let sym = dlsym(handle, "MTDeviceStart") {
            MTDeviceStart = unsafeBitCast(sym, to: (@convention(c) (MTDeviceRef, Int32) -> Void).self)
        }
        if let sym = dlsym(handle, "MTDeviceStop") {
            MTDeviceStop = unsafeBitCast(sym, to: (@convention(c) (MTDeviceRef, Int32) -> Void).self)
        }
    }
    
    /// Starts monitoring multi-touch events on all available trackpads.
    public func start() {
        guard !isRunning, let createList = MTDeviceCreateList else { return }
        
        // Retain the devices
        let deviceList = createList() as [AnyObject]
        self.activeDevices = deviceList
        
        for deviceObj in activeDevices {
             let device = unsafeBitCast(deviceObj, to: MTDeviceRef.self)
             
             // Register callback
             MTRegisterContactFrameCallback?(device, globalContactCallback)
             
             // Start
             MTDeviceStart?(device, 0)
        }
        isRunning = true
        Output.shared.announce("Touch Interface Enabled")
    }
    
    /// Stops monitoring multi-touch events.
    public func stop() {
        guard isRunning else { return }
        for deviceObj in activeDevices {
            let device = unsafeBitCast(deviceObj, to: MTDeviceRef.self)
            MTDeviceStop?(device, 0)
        }
        activeDevices.removeAll()
        isRunning = false
    }
    
    /// Internal handler for processed callbacks.
    ///
    /// - Parameters:
    ///   - device: The device reference.
    ///   - contacts: Pointer to the contact array.
    ///   - numContacts: Number of active fingers.
    /// Internal handler for processed callbacks.
    ///
    /// - Parameters:
    ///   - device: The device reference.
    ///   - contacts: Pointer to the contact array.
    ///   - numContacts: Number of active fingers.
    fileprivate func handleCallback(device: MTDeviceRef, contacts: UnsafeMutableRawPointer, numContacts: Int32) {
        var centroid = CGPoint.zero
        if numContacts > 0 {
             let contactSize = 512 + MemoryLayout<Int>.size // Rough stride for MTContact (typically huge struct)
             // Using proper struct binding is safer if we define it, but for now we iterate
             // Let's assume the first contact's position is enough for now
             let contact = contacts.load(as: MTContact.self)
             centroid = CGPoint(x: CGFloat(contact.normalizedPosition.x), y: CGFloat(contact.normalizedPosition.y))
        }
        
        Task { @MainActor in
             GestureRecognizer.shared.update(contactCount: Int(numContacts), position: centroid)
        }
    }
}

/// Minimal representation of the internal MTContact structure.
struct MTContact {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalizedPosition: MTVector
    // ... many more fields ignore
}

struct MTVector {
    var x: Float
    var y: Float
}

/// Global C-compatible callback function that bridges to the Swift singleton.
private func globalContactCallback(device: OpaquePointer, data: Int32, numContacts: Int32, contacts: UnsafeMutableRawPointer, frame: Int32, timestamp: Double, unk: Int32) {
    Task { @MainActor in
        MultitouchManager.shared.handleCallback(device: device, contacts: contacts, numContacts: numContacts)
    }
}

/// Analyzes sequences of finger counts to recognize taps.
///
/// Determines gestures like "2-finger tap" by observing transitions in contact count
/// (e.g., 0 -> 2 -> 0 within a short timeframe).
@MainActor
class GestureRecognizer {
    
    /// Shared singleton instance.
    static let shared = GestureRecognizer()
    
    /// The number of fingers seen in the previous frame.
    private var lastContactCount = 0
    
    /// Timestamp when fingers first touched down.
    private var tapStartTime: Double = 0
    
    /// Position when fingers first touched down.
    private var startPosition: CGPoint = .zero
    
    /// Updates the recognizer state with the current number of fingers.
    /// - Parameter contactCount: Current number of fingers touching the trackpad.
    /// - Parameter position: Normalized centroid of contacts.
    func update(contactCount: Int, position: CGPoint) {
        if contactCount != lastContactCount {
            let now = Date().timeIntervalSince1970
            
            // Detect Touch Down
            if contactCount > lastContactCount {
                tapStartTime = now
                if lastContactCount == 0 {
                    startPosition = position
                }
            } 
            // Detect Touch Up (Potential Tap)
            else if contactCount < lastContactCount {
                let duration = now - tapStartTime
                let distance = hypot(position.x - startPosition.x, position.y - startPosition.y)
                
                // Thresholds: Time < 0.25s, Distance < 0.05 (normalized 0-1)
                // If moved more than 5% of trackpad, it's a swipe/move, not a tap.
                if duration < 0.25 && distance < 0.05 { 
                    
                    // Tap Heuristic:
                    // If we go from N fingers to 0 fingers quickly, assume it was an N-finger tap.
                    // This logic simplifies complex cases (like rolling fingers) but works for basic taps.
                    
                    if lastContactCount == 1 && contactCount == 0 {
                        handleTap(fingers: 1)
                    } else if lastContactCount == 2 && contactCount == 0 {
                         handleTap(fingers: 2)
                    } else if lastContactCount == 3 && contactCount == 0 {
                         handleTap(fingers: 3)
                    } else if lastContactCount == 4 && contactCount == 0 {
                         handleTap(fingers: 4)
                    }
                }
            }
            lastContactCount = contactCount
        }
    }
    
    /// Executes the command associated with a recognized multi-finger tap.
    /// - Parameter fingers: The number of fingers involved in the tap.
    private func handleTap(fingers: Int) {
        switch fingers {
        case 1:
            // Single finger tap -> Stop Speech
            Output.shared.interrupt()
        case 2:
            // Two finger tap -> Pause/Resume (Speech or Media)
             Output.shared.announce("Pause/Resume")
        case 3:
             Output.shared.announce("Read from top")
        case 4:
             Output.shared.announce("Toggle Curtain")
        default: break
        }
    }
}
