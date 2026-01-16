//
//  PhotoPreviewView.swift
//  ProAlarm
//
//  Preview captured photo with Use/Retake options and awakeness validation
//

import SwiftUI

struct PhotoPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ViewModel

    let image: UIImage
    let onUse: () -> Void
    let onRetake: () -> Void

    private let maxRetries = 3

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 30) {
                    Spacer()

                    // Photo preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 10)
                        .padding()

                    Spacer()

                    // Status text based on validation state
                    statusText

                    // Action buttons (hidden during validation)
                    if !viewModel.awakenessValidationState.isValidating {
                        actionButtons
                    }
                }

                // Validation overlay
                if viewModel.awakenessValidationState != .idle {
                    AwakenessValidationOverlay(
                        state: viewModel.awakenessValidationState,
                        onRetry: handleRetry,
                        onBypass: viewModel.validationRetryCount >= maxRetries ? handleBypass : nil,
                        retryCount: viewModel.validationRetryCount
                    )
                    .transition(.opacity)
                }
            }
            .navigationTitle("Photo Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.retryPhotoCapture()
                        onRetake()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: viewModel.awakenessValidationState) { oldValue, newValue in
            // Auto-dismiss on successful validation
            if case .passed = newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onUse()
                }
            }
        }
    }

    // MARK: - Status Text

    @ViewBuilder
    private var statusText: some View {
        switch viewModel.awakenessValidationState {
        case .idle:
            if AppSettings.shared.awakeDetectionEnabled {
                Text("Analyzing your alertness...")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                Text("Use this photo as proof?")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

        case .validating:
            Text("Checking if you're awake...")
                .font(.headline)
                .foregroundStyle(.blue)

        case .passed(let score):
            VStack(spacing: 8) {
                Text("Looking awake!")
                    .font(.headline)
                    .foregroundStyle(.green)
                if score > 0 {
                    Text("Alertness: \(Int(score * 100))%")
                        .font(.caption)
                        .foregroundStyle(.green.opacity(0.8))
                }
            }

        case .failed(let reason, _):
            Text(reason.userMessage)
                .font(.headline)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        // If validation is disabled, show original buttons
        if !AppSettings.shared.awakeDetectionEnabled {
            originalButtons
        } else {
            // If validation is enabled but not started (idle), it will auto-start
            // If validation passed, buttons are hidden (auto-dismiss)
            // If validation failed, show retry in overlay
            if viewModel.awakenessValidationState == .idle {
                // Waiting for validation to start
                ProgressView()
                    .tint(.white)
                    .padding(.bottom, 30)
            }
        }
    }

    private var originalButtons: some View {
        HStack(spacing: 20) {
            // Retake button
            Button {
                onRetake()
            } label: {
                Label("Retake", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            // Use photo button
            Button {
                onUse()
            } label: {
                Label("Use Photo", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }

    // MARK: - Actions

    private func handleRetry() {
        viewModel.retryPhotoCapture()
        onRetake()
    }

    private func handleBypass() {
        viewModel.bypassValidation()
        // Will trigger onUse via onChange when state becomes .passed
    }
}

#Preview("No Validation") {
    let vm = ViewModel()
    return PhotoPreviewView(
        viewModel: vm,
        image: UIImage(systemName: "photo")!,
        onUse: {},
        onRetake: {}
    )
}
