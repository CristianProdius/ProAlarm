//
//  AwakenessValidator.swift
//  ProAlarm
//
//  Uses Vision Framework to analyze proof photos and verify
//  the user appears awake (eyes open, face visible).
//

import Foundation
import Vision
import UIKit
import SwiftUI

// MARK: - Awakeness Result

struct AwakenessResult {
    let isAwake: Bool
    let awakenessScore: Float  // 0.0-1.0
    let feedback: String       // User-friendly message
    let failureReason: FailureReason?

    static let passed = AwakenessResult(
        isAwake: true,
        awakenessScore: 1.0,
        feedback: "Looking alert! Great job.",
        failureReason: nil
    )

    static func failed(_ reason: FailureReason) -> AwakenessResult {
        AwakenessResult(
            isAwake: false,
            awakenessScore: 0.0,
            feedback: reason.userMessage,
            failureReason: reason
        )
    }
}

// MARK: - Failure Reason

enum FailureReason: Equatable {
    case noFaceDetected
    case eyesClosed
    case faceTooSmall
    case poorQuality
    case multipleFaces

    var userMessage: String {
        switch self {
        case .noFaceDetected:
            return "Face not visible - center your face in frame"
        case .eyesClosed:
            return "Eyes appear closed - please open your eyes"
        case .faceTooSmall:
            return "Face too far away - move closer to camera"
        case .poorQuality:
            return "Photo too blurry - hold steady"
        case .multipleFaces:
            return "Multiple faces detected - only you should be in frame"
        }
    }

    var icon: String {
        switch self {
        case .noFaceDetected: return "person.fill.questionmark"
        case .eyesClosed: return "eye.slash.fill"
        case .faceTooSmall: return "arrow.up.left.and.arrow.down.right"
        case .poorQuality: return "camera.metering.unknown"
        case .multipleFaces: return "person.2.fill"
        }
    }
}

// MARK: - Awakeness Validator

@Observable
@MainActor
class AwakenessValidator {

    // Configuration
    private let minimumFaceSize: Float = 0.15  // Face must be at least 15% of image
    private let eyeOpenThreshold: Float = 0.25  // EAR threshold for open eyes
    private var sensitivity: Float = 0.7  // 0.5-0.9 from settings

    var isValidating = false
    var lastResult: AwakenessResult?

    init(sensitivity: Float = 0.7) {
        self.sensitivity = max(0.5, min(0.9, sensitivity))
    }

    func updateSensitivity(_ newSensitivity: Float) {
        sensitivity = max(0.5, min(0.9, newSensitivity))
    }

    // MARK: - Main Validation

    func validatePhoto(_ image: UIImage) async -> AwakenessResult {
        isValidating = true
        defer { isValidating = false }

        guard let cgImage = image.cgImage else {
            let result = AwakenessResult.failed(.poorQuality)
            lastResult = result
            return result
        }

        do {
            let result = try await performVisionAnalysis(cgImage: cgImage)
            lastResult = result
            return result
        } catch {
            print("Vision analysis error: \(error)")
            let result = AwakenessResult.failed(.poorQuality)
            lastResult = result
            return result
        }
    }

    // MARK: - Vision Analysis

    private func performVisionAnalysis(cgImage: CGImage) async throws -> AwakenessResult {
        return try await withCheckedThrowingContinuation { continuation in
            // Create face landmarks request
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
                guard let self = self else {
                    continuation.resume(returning: .failed(.poorQuality))
                    return
                }

                if let error = error {
                    print("Face landmarks error: \(error)")
                    continuation.resume(returning: .failed(.poorQuality))
                    return
                }

                guard let observations = request.results as? [VNFaceObservation],
                      !observations.isEmpty else {
                    continuation.resume(returning: .failed(.noFaceDetected))
                    return
                }

                // Check for multiple faces
                if observations.count > 1 {
                    continuation.resume(returning: .failed(.multipleFaces))
                    return
                }

                guard let face = observations.first else {
                    continuation.resume(returning: .failed(.noFaceDetected))
                    return
                }

                let result = self.analyzeFace(face)
                continuation.resume(returning: result)
            }

            // Also perform face capture quality request for blur detection
            let qualityRequest = VNDetectFaceCaptureQualityRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([faceLandmarksRequest, qualityRequest])

                // Check quality if available
                if let qualityResults = qualityRequest.results,
                   let firstQuality = qualityResults.first,
                   let quality = firstQuality.faceCaptureQuality,
                   quality < 0.3 {
                    continuation.resume(returning: .failed(.poorQuality))
                    return
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Face Analysis

    private func analyzeFace(_ observation: VNFaceObservation) -> AwakenessResult {
        let boundingBox = observation.boundingBox

        // Check face size (must be at least minimumFaceSize of image)
        let faceArea = boundingBox.width * boundingBox.height
        if faceArea < CGFloat(minimumFaceSize) {
            return .failed(.faceTooSmall)
        }

        // Check for landmarks (needed for eye detection)
        guard let landmarks = observation.landmarks else {
            // No landmarks but face detected - likely poor quality
            return .failed(.poorQuality)
        }

        // Calculate Eye Aspect Ratio (EAR) for both eyes
        let leftEyeOpen = isEyeOpen(landmarks.leftEye)
        let rightEyeOpen = isEyeOpen(landmarks.rightEye)

        // Calculate overall awakeness score
        let eyeScore = calculateEyeScore(leftOpen: leftEyeOpen, rightOpen: rightEyeOpen)
        let adjustedThreshold = 0.5 + (sensitivity - 0.5) * 0.5  // Adjust threshold based on sensitivity

        if eyeScore < Float(adjustedThreshold) {
            return AwakenessResult(
                isAwake: false,
                awakenessScore: eyeScore,
                feedback: FailureReason.eyesClosed.userMessage,
                failureReason: .eyesClosed
            )
        }

        // Success!
        let feedback = awakenessMessage(for: eyeScore)
        return AwakenessResult(
            isAwake: true,
            awakenessScore: eyeScore,
            feedback: feedback,
            failureReason: nil
        )
    }

    // MARK: - Eye Aspect Ratio Calculation

    private func isEyeOpen(_ eye: VNFaceLandmarkRegion2D?) -> Bool {
        guard let eye = eye, eye.pointCount >= 6 else {
            // If we can't detect the eye, assume it's open (benefit of doubt)
            return true
        }

        let points = eye.normalizedPoints

        // Eye Aspect Ratio (EAR) calculation
        // EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
        // For a 6-point eye model:
        // p1 = outer corner, p4 = inner corner
        // p2, p3 = top, p5, p6 = bottom

        guard points.count >= 6 else { return true }

        // Calculate vertical distances
        let verticalDist1 = distance(points[1], points[5])
        let verticalDist2 = distance(points[2], points[4])

        // Calculate horizontal distance
        let horizontalDist = distance(points[0], points[3])

        guard horizontalDist > 0 else { return true }

        let ear = (verticalDist1 + verticalDist2) / (2.0 * horizontalDist)

        return ear > CGFloat(eyeOpenThreshold)
    }

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }

    private func calculateEyeScore(leftOpen: Bool, rightOpen: Bool) -> Float {
        switch (leftOpen, rightOpen) {
        case (true, true): return 1.0
        case (true, false), (false, true): return 0.5
        case (false, false): return 0.0
        }
    }

    // MARK: - Feedback Messages

    private func awakenessMessage(for score: Float) -> String {
        switch score {
        case 0.9...1.0:
            return "Looking bright and alert!"
        case 0.7..<0.9:
            return "Good enough! Eyes detected open."
        case 0.5..<0.7:
            return "Barely awake, but we'll take it!"
        default:
            return "Verification passed."
        }
    }
}

// MARK: - Validation State

enum ValidationState: Equatable {
    case idle
    case validating
    case passed(score: Float)
    case failed(reason: FailureReason, retryCount: Int)

    var isValidating: Bool {
        if case .validating = self { return true }
        return false
    }

    var isPassed: Bool {
        if case .passed = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
