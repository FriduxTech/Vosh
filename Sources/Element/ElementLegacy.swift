//
//  ElementLegacy.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import ApplicationServices

/// A protocol that enables seamless conversion between modern Swift types and CoreFoundation (CF) legacy types.
///
/// Adopting `ElementLegacy` allows a type to be initialized from a `CFTypeRef` and to export itself
/// back to a `CFTypeRef`. This is essential for communicating with the underlying C-based Accessibility API
/// which relies heavily on `CFTypeRef`, `AXValue`, and generic containers.
protocol ElementLegacy {
    
    /// Initializes the complying Swift type from a legacy CoreFoundation reference.
    ///
    /// - Parameter value: The raw `CFTypeRef` to convert.
    init?(legacyValue value: CFTypeRef)
    
    /// The CoreFoundation representation of the Swift instance.
    var legacyValue: CFTypeRef {get}
}

extension Optional where Wrapped: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) != CFNullGetTypeID() else {
            return nil
        }
        self = Wrapped(legacyValue: value)
    }

    var legacyValue: CFTypeRef {
        switch self {
        case .some(let value):
            return value.legacyValue as CFTypeRef
        case .none:
            return kCFNull
        }
    }
}

extension Bool: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFBooleanGetTypeID() else {
            return nil
        }
        let boolean = unsafeBitCast(value, to: CFBoolean.self)
        self = CFBooleanGetValue(boolean)
    }

    var legacyValue: CFTypeRef {
        return self ? kCFBooleanTrue : kCFBooleanFalse
    }
}

extension Int64: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFNumberGetTypeID() else {
            return nil
        }
        let number = unsafeBitCast(value, to: CFNumber.self)
        var integer = Int64(0)
        guard CFNumberGetValue(number, .sInt64Type, &integer) else {
            return nil
        }
        guard let integer = Self(exactly: integer) else {
            return nil
        }
        self = integer
    }

    var legacyValue: CFTypeRef {
        var integer = self
        return CFNumberCreate(nil, .sInt64Type, &integer)
    }
}

extension Double: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFNumberGetTypeID() else {
            return nil
        }
        let number = unsafeBitCast(value, to: CFNumber.self)
        var float = Double(0.0)
        guard CFNumberGetValue(number, .doubleType, &float) else {
            return nil
        }
        guard let float = Self(exactly: float) else {
            return nil
        }
        self = float
    }

    var legacyValue: CFTypeRef {
        var float = self
        return CFNumberCreate(nil, .doubleType, &float)
    }
}

extension String: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFStringGetTypeID() else {
            return nil
        }
        self = unsafeBitCast(value, to: CFString.self) as String
    }

    var legacyValue: CFTypeRef {
        return self as CFString
    }
}

extension [Any?]: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFArrayGetTypeID() else {
            return nil
        }
        let array = unsafeBitCast(value, to: CFArray.self) as! Array
        self = Self()
        self.reserveCapacity(array.count)
        for element in array {
            self.append(fromLegacy(value: element as CFTypeRef))
        }
    }

    var legacyValue: CFTypeRef {
        return self as CFArray
    }
}

extension [String: Any]: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFDictionaryGetTypeID() else {
            return nil
        }
        let dictionary = unsafeBitCast(value, to: CFDictionary.self) as! Self
        self = Self()
        self.reserveCapacity(dictionary.count)
        for pair in dictionary {
            guard let key = fromLegacy(value: pair.key as CFTypeRef) as? String, let value = fromLegacy(value: pair.value as CFTypeRef) else {
                continue
            }
            self[key] = value
        }
    }

    var legacyValue: CFTypeRef {
        return self as CFDictionary
    }
}

extension URL: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFURLGetTypeID() else {
            return nil
        }
        let url = unsafeBitCast(value, to: CFURL.self)
        self = url as URL
    }

    var legacyValue: CFTypeRef {
        return self as CFURL
    }
}

extension AttributedString: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == CFAttributedStringGetTypeID() else {
            return nil
        }
        let attributedString = unsafeBitCast(value, to: CFAttributedString.self) as NSAttributedString
        self = AttributedString(attributedString as NSAttributedString)
    }

    var legacyValue: CFTypeRef {
        return NSAttributedString(self) as CFAttributedString
    }
}

/// A type that can be boxed into and unboxed from an `AXValue`.
protocol AXValueBoxable {
    static var axValueType: AXValueType { get }
}

extension AXValueBoxable {
    /// Boxes the value into an `AXValue`.
    func toAXValue() -> AXValue? {
        var value = self
        return AXValueCreate(Self.axValueType, &value)
    }
    
    /// Unboxes an `AXValue` into this type.
    static func from(axValue: AXValue) -> Self? {
        guard AXValueGetType(axValue) == Self.axValueType else { return nil }
        // We use a dummy initialized var to hold the result
        // Swift requires initialization. For structs we can usually just verify size/type matches.
        // Unsafe logic:
        let pointer = UnsafeMutablePointer<Self>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        
        // We can't easily init 'Self' if we don't know it, but we can write TO the pointer.
        // AXValuegetValue writes to the pointer.
        guard AXValueGetValue(axValue, Self.axValueType, pointer) else { return nil }
        return pointer.move()
    }
}

extension CGPoint: AXValueBoxable { static var axValueType: AXValueType { .cgPoint } }
extension CGSize: AXValueBoxable { static var axValueType: AXValueType { .cgSize } }
extension CGRect: AXValueBoxable { static var axValueType: AXValueType { .cgRect } }
extension CFRange: AXValueBoxable { static var axValueType: AXValueType { .cfRange } }

// Bridge the generic logic to ElementLegacy
extension CGPoint {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        guard let val = Self.from(axValue: value as! AXValue) else { return nil }
        self = val
    }
    var legacyValue: CFTypeRef { return toAXValue() ?? kCFNull }
}

extension CGSize {
    init?(legacyValue value: CFTypeRef) {
         guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
         guard let val = Self.from(axValue: value as! AXValue) else { return nil }
         self = val
    }
    var legacyValue: CFTypeRef { return toAXValue() ?? kCFNull }
}

extension CGRect {
    init?(legacyValue value: CFTypeRef) {
         guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
         guard let val = Self.from(axValue: value as! AXValue) else { return nil }
         self = val
    }
    var legacyValue: CFTypeRef { return toAXValue() ?? kCFNull }
}

extension Range: ElementLegacy where Bound == Int {
    init?(legacyValue value: CFTypeRef) {
         guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
         guard let cfRange = CFRange.from(axValue: value as! AXValue) else { return nil }
         self = Int(cfRange.location) ..< Int(cfRange.location + cfRange.length)
    }
    var legacyValue: CFTypeRef {
        let cfRange = CFRangeMake(self.lowerBound, self.upperBound - self.lowerBound)
        return cfRange.toAXValue() ?? kCFNull
    }
}
extension ElementError: ElementLegacy {
    init?(legacyValue value: CFTypeRef) {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let value = unsafeBitCast(value, to: AXValue.self)
        var error = AXError.success
        guard AXValueGetValue(value, .axError, &error) else {
            return nil
        }
        self = ElementError(from: error)
    }

    var legacyValue: CFTypeRef {
        var error = self.toAXError()
        return AXValueCreate(.axError, &error)!
    }
}

extension Element: ElementLegacy {}

/// Intelligently converts an arbitrary legacy `CFTypeRef` into its corresponding Swift type.
///
/// This factory function inspects the type ID of the provided CoreFoundation reference
/// and delegates to the appropriate `ElementLegacy` initializer. It handles primitives,
/// collections, geometric structs (`AXValue`), error codes, and accessibility elements.
///
/// - Parameter value: The raw `CFTypeRef` to convert. Can be nil.
/// - Returns: A native Swift type (`String`, `Int64`, `CGRect`, `Element`, etc.) or `nil` if unrecognized.
func fromLegacy(value: CFTypeRef?) -> Any? {
    guard let value = value else {
        return nil
    }
    guard CFGetTypeID(value) != CFNullGetTypeID() else {
        return nil
    }
    if let boolean = Bool(legacyValue: value) {
        return boolean
    }
    if let integer = Int64(legacyValue: value) {
        return integer
    }
    if let float = Double(legacyValue: value) {
        return float
    }
    if let string = String(legacyValue: value) {
        return string
    }
    if let array = [Any?](legacyValue: value) {
        return array
    }
    if let dictionary = [String: Any](legacyValue: value) {
        return dictionary
    }
    if let url = URL(legacyValue: value) {
        return url
    }
    if let attributedString = AttributedString(legacyValue: value) {
        return attributedString
    }
    if let range = Range(legacyValue: value) {
        return range
    }
    if let point = CGPoint(legacyValue: value) {
        return point
    }
    if let size = CGSize(legacyValue: value) {
        return size
    }
    if let rect = CGRect(legacyValue: value) {
        return rect
    }
    if let error = ElementError(legacyValue: value) {
        return error
    }
    if let element = Element(legacyValue: value) {
        return element
    }
    return nil
}
