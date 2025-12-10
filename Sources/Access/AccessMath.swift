//
//  AccessMath.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Foundation
import Element

/// A specialized handler for interacting with and navigating Math content.
///
/// This class handles the extraction of equation descriptions and manages the specific
/// hierarchical structure of mathematical elements (like fractions, roots, subscripts),
/// which often uses specific attributes rather than standard child traversal.
@AccessActor final class AccessMath {
    
    /// The root element containing the math content.
    private let root: Element
    
    /// Initializes a new math accessor for the given root element.
    ///
    /// - Parameter root: The root `Element` with role `.math`.
    init(root: Element) {
        self.root = root
    }
    
    /// Retrieves a textual description of the equation.
    ///
    /// This method prioritizes the accessibility description. If unavailable, it acknowledges the presence
    /// of MathML content, or returns a generic label.
    ///
    /// - Returns: A string suitable for voiceover announcement.
    func getEquation() async -> String {
        // AXDescription or AXRoleDescription
        if let desc = try? await root.getAttribute(.description) as? String, !desc.isEmpty {
            return "Math: " + desc
        }
        if (try? await root.getAttribute(.mathML) as? String) != nil {
            return "Math content" // Raw MathML might be too verbose for default announcement
        }
        return "Math"
    }
    
    /// Retrieves the child elements for structural math navigation.
    ///
    /// Math content often exposes its structure (numerator, denominator, base, index) via specific attributes
    /// instead of a simple child list. This method aggregates standard children and known structural attributes.
    ///
    /// - Returns: A list of child `Element`s representing the sub-parts of the math expression.
    func getChildren() async -> [Element] {
        // 1. Standard Children
        if let children = try? await root.getAttribute(.childElements) as? [Element], !children.isEmpty {
            return children
        }
        
        // 2. Structural Attributes (Explicit)
        var kids = [Element]()
        
        func add(_ attr: ElementAttribute) async {
            if let el = try? await root.getAttribute(attr) as? Element {
                kids.append(el)
            }
        }
        
        // Common Math Structures
        await add(.mathFractionNumerator)
        await add(.mathFractionDenominator)
        await add(.mathRootIndex)
        await add(.mathRootRadicand)
        await add(.mathBase)
        await add(.mathSubscript)
        await add(.mathSuperscript)
        await add(.mathUnder)
        await add(.mathOver)
        
        return kids
    }
}
