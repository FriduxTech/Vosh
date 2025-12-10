//
//  VisionService.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Cocoa
import Vision

/// Service for visual recognition and image analysis.
///
/// `VisionService` leverages Apple's Vision framework to provide Optical Character Recognition (OCR),
/// image classification, and scene description capabilities for Vosh's screen reader functionality.
@MainActor
public final class VisionService {
    
    /// Shared singleton instance.
    public static let shared = VisionService()
    
    /// Initializes the vision service.
    private init() {}
    
    /// Recognizes text in the given image.
    ///
    /// Uses `VNRecognizeTextRequest` with high-accuracy settings to extract text from screenshots or UI snapshots.
    ///
    /// - Parameter image: The `CGImage` to process.
    /// - Returns: A string containing all recognized text, lines joined by newlines.
    /// - Throws: An error if the request fails (from the Vision framework).
    public func recognizeText(in image: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Classifies the image to provide a basic description.
    ///
    /// Uses `VNClassifyImageRequest` to identify objects or scenes within the image.
    ///
    /// - Parameter image: The `CGImage` to classify.
    /// - Returns: A string describing the top 3 confidence results (e.g., "Image contains: keyboard, computer_keyboard, laptop").
    /// - Throws: An error if classification fails.
    public func describeImage(_ image: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: "No description available")
                    return
                }
                
                // Get top 3 classifications
                let descriptions = observations.prefix(3).map { $0.identifier }.joined(separator: ", ")
                continuation.resume(returning: "Image contains: " + descriptions)
            }
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Asks a question about the image context (e.g., "What is in this window?").
    ///
    /// Combines OCR and Image Classification to provide a contextual answer. In a future implementation,
    /// this might connect to a multimodal LLM for richer analysis.
    ///
    /// - Parameters:
    ///   - query: The user's natural language question.
    ///   - image: The image context.
    /// - Returns: A synthesized answer string based on available visual data.
    public func ask(query: String, image: CGImage) async throws -> String {
        // 1. Recognize Text
        let text = try? await recognizeText(in: image)
        
        // 2. Classify Image
        let description = try? await describeImage(image)
        
        // 3. Synthesize Answer (Mocked for MVP)
        return "Analyzed Context. Q: \"\(query)\". \nText: \(text?.prefix(50) ?? "None")... \nVisuals: \(description ?? "None")."
    }
}

/// Errors related to screen capture and snapshotting.
public enum SnapshotError: Error {
    /// Failed to capture the screen image.
    case captureFailed
}

/// Helper methods for capturing screen content.
public enum SnapshotManager {
    
    /// Captures the entire primary screen.
    ///
    /// - Returns: A `CGImage` of the screen content, or `nil` if capture failed.
    public static func captureScreen() -> CGImage? {
        return CGWindowListCreateImage(CGRect.infinite, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
    }
    
    /// Captures a specific rectangular region of the screen.
    ///
    /// - Parameter rect: The screen coordinates to capture.
    /// - Returns: A `CGImage` of the region, or `nil` if capture failed.
    public static func captureRegion(_ rect: CGRect) -> CGImage? {
        return CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
    }
}
