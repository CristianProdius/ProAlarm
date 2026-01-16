//
//  AwakenessValidationOverlay.swift
//  ProAlarm
//
//  Shows scanning animation during awakeness validation
//  and displays real-time feedback.
//

import SwiftUI

struct AwakenessValidationOverlay: View {
    let state: ValidationState
    let onRetry: () -> Void
    let onBypass: (() -> Void)?
    let retryCount: Int

    @State private var scanLineOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    private let maxRetries = 3

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Status icon and animation
                statusView

                // Message
                Text(statusMessage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Detailed feedback for failures
                if case .failed(let reason, _) = state {
                    failureDetailView(reason: reason)
                }

                // Action buttons
                actionButtons
            }
            .padding(32)
        }
    }

    // MARK: - Status View

    @ViewBuilder
    private var statusView: some View {
        switch state {
        case .idle:
            EmptyView()

        case .validating:
            ZStack {
                // Scanning circle
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(scanLineOffset))

                Image(systemName: "faceid")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                    .scaleEffect(pulseScale)
            }
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    scanLineOffset = 360
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }
            }

        case .passed(let score):
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }

                // Awakeness score indicator
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < Int(score * 5) ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }

                Text("Awakeness: \(Int(score * 100))%")
                    .font(.caption)
                    .foregroundColor(.green)
            }

        case .failed(let reason, _):
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(Color.red, lineWidth: 4)
                        .frame(width: 120, height: 120)

                    Image(systemName: reason.icon)
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }

                // Retry indicator
                HStack(spacing: 8) {
                    ForEach(0..<maxRetries) { index in
                        Circle()
                            .fill(index < retryCount ? Color.red : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }

                Text("Attempt \(retryCount) of \(maxRetries)")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }

    // MARK: - Failure Detail View

    private func failureDetailView(reason: FailureReason) -> some View {
        VStack(spacing: 16) {
            // Checklist of requirements
            VStack(alignment: .leading, spacing: 8) {
                checklistItem(
                    "Face visible in frame",
                    passed: reason != .noFaceDetected && reason != .faceTooSmall
                )
                checklistItem(
                    "Eyes open and visible",
                    passed: reason != .eyesClosed
                )
                checklistItem(
                    "Photo is clear",
                    passed: reason != .poorQuality
                )
                checklistItem(
                    "Only one face in frame",
                    passed: reason != .multipleFaces
                )
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private func checklistItem(_ text: String, passed: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(passed ? .green : .red)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch state {
        case .idle, .validating:
            EmptyView()

        case .passed:
            // Auto-dismiss after success
            EmptyView()

        case .failed(_, let currentRetryCount):
            VStack(spacing: 12) {
                // Retake button
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Retake Photo")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }

                // Bypass option after max retries
                if currentRetryCount >= maxRetries, let bypass = onBypass {
                    Button(action: bypass) {
                        VStack(spacing: 4) {
                            Text("Skip Verification")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            Text("(Affects streak achievements)")
                                .font(.caption2)
                                .foregroundColor(.orange.opacity(0.7))
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Status Message

    private var statusMessage: String {
        switch state {
        case .idle:
            return ""
        case .validating:
            return "Analyzing photo...\nMake sure your face is visible"
        case .passed:
            return "Verification passed!"
        case .failed(let reason, _):
            return reason.userMessage
        }
    }
}

// MARK: - Validation Criteria View

struct ValidationCriteriaView: View {
    let faceDetected: Bool?
    let eyesOpen: Bool?
    let photoQuality: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Verification Checklist")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            criteriaRow("Face visible", status: faceDetected)
            criteriaRow("Eyes open", status: eyesOpen)
            criteriaRow("Clear photo", status: photoQuality)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }

    private func criteriaRow(_ text: String, status: Bool?) -> some View {
        HStack {
            Group {
                if let status = status {
                    Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(status ? .green : .red)
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .frame(width: 20)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Validating") {
    AwakenessValidationOverlay(
        state: .validating,
        onRetry: {},
        onBypass: nil,
        retryCount: 0
    )
}

#Preview("Passed") {
    AwakenessValidationOverlay(
        state: .passed(score: 0.92),
        onRetry: {},
        onBypass: nil,
        retryCount: 1
    )
}

#Preview("Failed - Eyes Closed") {
    AwakenessValidationOverlay(
        state: .failed(reason: .eyesClosed, retryCount: 2),
        onRetry: {},
        onBypass: nil,
        retryCount: 2
    )
}

#Preview("Failed - Max Retries") {
    AwakenessValidationOverlay(
        state: .failed(reason: .eyesClosed, retryCount: 3),
        onRetry: {},
        onBypass: { },
        retryCount: 3
    )
}
