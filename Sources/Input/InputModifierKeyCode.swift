//
//  InputModifierKeyCode.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// Enumeration of low-level hardware scan codes for modifier keys.
///
/// Ref: IOHIDUsageTables.h (kHIDUsage_Keyboard...)
/// These values represent the physical keys on the keyboard used as modifiers.
/// Unlike standard key codes, the left and right versions of modifiers often have distinct usage IDs
/// in the HID specification.
public enum InputModifierKeyCode: UInt32 {
    
    /// The Caps Lock key.
    case capsLock = 0x39
    
    /// The Left Shift key.
    case leftShift = 0xe1
    
    /// The Left Control key.
    case leftControl = 0xe0
    
    /// The Left Option (Alt) key.
    case leftOption = 0xe2
    
    /// The Left Command (GUI) key.
    case leftCommand = 0xe3
    
    /// The Right Shift key.
    case rightShift = 0xe5
    
    /// The Right Control key.
    case rightControl = 0xe4
    
    /// The Right Option (Alt) key.
    case rightOption = 0xe6
    
    /// The Right Command (GUI) key.
    case rightCommand = 0xe7
    
    /// The Function (Fn) key (hardware dependent).
    case function = 0x3
}

extension InputModifierKeyCode: CustomStringConvertible {
    
    /// A human-readable name for the modifier key.
    public var description: String {
        switch self {
        case .capsLock: return "Caps Lock"
        case .leftShift: return "Left Shift"
        case .leftControl: return "Left Control"
        case .leftOption: return "Left Option"
        case .leftCommand: return "Left Command"
        case .rightShift: return "Right Shift"
        case .rightControl: return "Right Control"
        case .rightOption: return "Right Option"
        case .rightCommand: return "Right Command"
        case .function: return "Function"
        }
    }
}
