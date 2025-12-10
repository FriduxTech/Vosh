//
//  AccessMathReader.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Element
import Output

@AccessActor class AccessMathReader: AccessGenericReader {
    
    private let math: AccessMath
    
    override init(for element: Element) async throws {
        self.math = AccessMath(root: element)
        try await super.init(for: element)
    }
    
    override func read() async throws -> [OutputSemantic] {
        // For Math, we prioritize the equation string over generic attributes
        let eq = await math.getEquation()
        return [.stringValue(eq), .help("Interact to explore terms")]
    }
    
    override func readSummary() async throws -> [OutputSemantic] {
        return try await read()
    }
}
