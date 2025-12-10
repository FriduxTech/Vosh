//
//  ModifierListener.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import IOKit
import CoreGraphics

/// Manages IOHIDManager interactions for Modifier keys and Caps Lock LED control.
@MainActor final class ModifierListener {
    
    private var hidManager: IOHIDManager?
    private var connect = io_connect_t(0)
    
    // Streams
    let capsLockStream: AsyncStream<(timestamp: UInt64, isDown: Bool)>
    private let capsLockContinuation: AsyncStream<(timestamp: UInt64, isDown: Bool)>.Continuation
    
    let modifierStream: AsyncStream<(key: InputModifierKeyCode, isDown: Bool)>
    private let modifierContinuation: AsyncStream<(key: InputModifierKeyCode, isDown: Bool)>.Continuation
    
    init() {
        (capsLockStream, capsLockContinuation) = AsyncStream<(timestamp: UInt64, isDown: Bool)>.makeStream()
        (modifierStream, modifierContinuation) = AsyncStream<(key: InputModifierKeyCode, isDown: Bool)>.makeStream()
        
        setupHID()
        setupLEDConnection()
    }
    
    private func setupHID() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matches = [
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad]
        ]
        
        guard let manager = hidManager else { return }
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
        
        let callback: IOHIDValueCallback = { (context, _, _, value) in
            guard let context = context else { return }
            let this = Unmanaged<ModifierListener>.fromOpaque(context).takeUnretainedValue()
            
            let isDown = IOHIDValueGetIntegerValue(value) != 0
            let timestamp = IOHIDValueGetTimeStamp(value)
            let element = IOHIDValueGetElement(value)
            let scanCode = IOHIDElementGetUsage(element)
            
            guard let modifier = InputModifierKeyCode(rawValue: scanCode) else { return }
            
            if modifier == .capsLock {
                this.capsLockContinuation.yield((timestamp: timestamp, isDown: isDown))
            }
            this.modifierContinuation.yield((key: modifier, isDown: isDown))
        }
        
        IOHIDManagerRegisterInputValueCallback(manager, callback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    
    private func setupLEDConnection() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        if service != 0 {
            IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
            IOObjectRelease(service)
        }
    }
    
    func getCapsLockState() -> Bool {
        var state = false
        if connect != 0 {
            IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state)
        }
        return state
    }
    
    func setCapsLockState(_ enabled: Bool) {
        if connect != 0 {
            IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), enabled)
        }
    }
    
    deinit {
        if connect != 0 {
             IOServiceClose(connect)
        }
        // hidManager run loop source removal implicit on release usually, or explicit if needed
    }
}
