//
//  ElementParameterizedAttribute.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// A type-safe enumeration of standard Parameterized Accessibility Attributes.
///
/// Parameterized attributes are similar to regular attributes but require an input parameter
/// to retrieve a value. For example, getting the screen bounds for a specific range of text.
/// These map directly to the `AXParameterizedAttribute` constant strings.
public enum ElementParameterizedAttribute: String {
    
    // MARK: - Text
    
    /// Returns the line number for a specific character index (`Int` -> `Int`).
    case lineForIndex = "AXLineForIndex"
    
    /// Returns the character range for a specific line number (`Int` -> `CFRange`).
    case rangeForLine = "AXRangeForLine"
    
    /// Returns the plain text string for a specific character range (`CFRange` -> `String`).
    case stringForRange = "AXStringForRange"
    
    /// Returns the character range at a specific screen point (`CGPoint` -> `CFRange`).
    case rangeForPosition = "AXRangeForPosition"
    
    /// Returns the character range for an index (often expanding to word/line boundaries) (`Int` -> `CFRange`).
    case rangeForIndex = "AXRangeForIndex"
    
    /// Returns the screen bounds (rect) for a specific character range (`CFRange` -> `CGRect`).
    case boundsForRange = "AXBoundsForRange"
    
    /// Returns the RTF data for a specific character range (`CFRange` -> `Data`).
    case rtfForRange = "AXRTFForRange"
    
    /// Returns the attributed string for a specific character range (`CFRange` -> `NSAttributedString`).
    case attributedStringForRange = "AXAttributedStringForRange"
    
    /// Returns the effective style range for a specific character index (`Int` -> `CFRange`).
    case styleRangeForIndex = "AXStyleRangeForIndex"

    // MARK: - Tables
    
    /// Returns the cell element at a specific column and row index (`[Int, Int]` -> `Element`).
    case cellForColumnAndRow = "AXCellForColumnAndRow"

    // MARK: - Layout Conversion
    
    /// Converts a global screen point to a window-relative layout point (`CGPoint` -> `CGPoint`).
    case layoutPointForScreenPoint = "AXLayoutPointForScreenPoint"
    
    /// Converts a global screen size to a window-relative layout size (`CGSize` -> `CGSize`).
    case layoutSizeForScreenSize = "AXLayoutSizeForScreenSize"
    
    /// Converts a window-relative layout point to a global screen point (`CGPoint` -> `CGPoint`).
    case screenPointForLayoutPoint = "AXScreenPointForLayoutPoint"
    
    /// Converts a window-relative layout size to a global screen size (`CGSize` -> `CGSize`).
    case screenSizeForLayoutSize = "AXScreenSizeForLayoutSize"
}
