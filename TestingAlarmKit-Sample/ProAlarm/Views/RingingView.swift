//
//  RingingView.swift
//  ProAlarm
//
//  Full-screen view when alarm is ringing, requires proof to stop
//

import SwiftUI

struct RingingView: View {
    @Environment(ViewModel.self) var viewModel
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var showCamera = false
    @State private var showQRScanner = false
    @State private var showPhotoPreview = false
    @State private var showStopConfirmation = false
    @State private var pulseAnimation = false
    @State private var textPulse = false
    @State private var stopButtonScale: CGFloat = 1.0
    @State private var ringingSeconds: Int = 0
    @State private var ringingTimer: Timer?
    @State private var previousProofCompleted = false

    private var alarm: WaterAlarm? {
        viewModel.currentlyRingingAlarm
    }

    private var metadata: WaterAlarmData? {
        viewModel.currentRingingMetadata
    }

    var body: some View {
        ZStack {
            // Animated background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Ringing indicator
                ringingHeader

                // Current time
                currentTimeDisplay

                // Alarm label
                if let label = alarm?.label, !label.isEmpty {
                    Text(label)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // Proof status
                proofStatusSection

                Spacer()

                // Action buttons
                actionButtonsSection

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                if let image = image {
                    viewModel.setCapturedPhoto(image)
                    showPhotoPreview = true
                }
            }
        }
        .sheet(isPresented: $showPhotoPreview) {
            if let photo = viewModel.capturedProofPhoto {
                PhotoPreviewView(
                    viewModel: viewModel,
                    image: photo,
                    onUse: {
                        showPhotoPreview = false
                        viewModel.startWaitTimeIfNeeded()
                    },
                    onRetake: {
                        showPhotoPreview = false
                        viewModel.capturedProofPhoto = nil
                        showCamera = true
                    }
                )
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView(
                expectedCode: alarm?.qrCodeIdentifier,
                onCodeScanned: { code in
                    if code == alarm?.qrCodeIdentifier || alarm?.qrCodeIdentifier == nil {
                        viewModel.setQRVerified(true)
                    }
                    showQRScanner = false
                }
            )
        }
        .onAppear {
            startRingingTimer()
            if !reduceMotion {
                pulseAnimation = true
            }
        }
        .onDisappear {
            stopRingingTimer()
        }
        .onChange(of: viewModel.isProofCompleted) { oldValue, newValue in
            if newValue && !oldValue {
                // Proof just completed - haptic feedback and animate stop button
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)

                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    stopButtonScale = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        stopButtonScale = 1.0
                    }
                }
            }
        }
        .alert("Complete Alarm?", isPresented: $showStopConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Complete", role: .none) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                viewModel.completeAlarm()
            }
        } message: {
            Text("Mark this alarm as complete and stop ringing?")
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                (pulseAnimation && !reduceMotion) ? Color.red.opacity(0.8) : Color.red.opacity(0.6),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1).repeatForever(autoreverses: true),
            value: pulseAnimation
        )
    }

    // MARK: - Ringing Header

    private var ringingHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "alarm.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)
                .scaleEffect((pulseAnimation && !reduceMotion) ? 1.1 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: pulseAnimation
                )

            Text("WAKE UP!")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect((textPulse && !reduceMotion) ? 1.05 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: textPulse
                )
                .onAppear {
                    if !reduceMotion {
                        textPulse = true
                    }
                }

            // AI Motivational Message (Apple Intelligence)
            if let message = viewModel.motivationalMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale))
            }

            if ringingSeconds > 0 {
                Text("Ringing for \(formatTime(ringingSeconds))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Current Time Display

    private var currentTimeDisplay: some View {
        Text(Date(), style: .time)
            .font(.system(size: 64, weight: .thin, design: .rounded))
            .foregroundStyle(.white)
    }

    // MARK: - Proof Status Section

    private var proofStatusSection: some View {
        VStack(spacing: 16) {
            Text("Complete proof to stop alarm")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            VStack(spacing: 12) {
                // Photo status
                if alarm?.requiresPhoto == true {
                    ProofStatusRow(
                        icon: "camera.fill",
                        title: "Take Photo",
                        isComplete: viewModel.capturedProofPhoto != nil
                    )
                }

                // QR status
                if alarm?.requiresQRCode == true || alarm?.qrRequiredForDifficulty == true {
                    ProofStatusRow(
                        icon: "qrcode",
                        title: "Scan QR Code",
                        isComplete: viewModel.isQRVerified
                    )
                }

                // Wait time status with progress
                if let waitTime = alarm?.waitTimeForDifficulty, waitTime > 0 {
                    WaitTimeProgressRow(
                        totalTime: waitTime,
                        remainingTime: viewModel.waitTimeRemaining,
                        isActive: viewModel.capturedProofPhoto != nil
                    )
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Snooze button (if allowed)
            if let metadata = metadata, metadata.snoozeAllowed, !(alarm?.snoozeUsed ?? true) {
                Button {
                    viewModel.snoozeCurrentAlarm()
                } label: {
                    Label("Snooze (3 min)", systemImage: "moon.zzz.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            // Take Photo button
            if alarm?.requiresPhoto == true && viewModel.capturedProofPhoto == nil {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            // QR Scanner button
            if (alarm?.requiresQRCode == true || alarm?.qrRequiredForDifficulty == true) && !viewModel.isQRVerified {
                Button {
                    showQRScanner = true
                } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }

            // Stop button (enabled only when proof complete)
            Button {
                showStopConfirmation = true
            } label: {
                Label(viewModel.isProofCompleted ? "Stop Alarm" : "Complete Proof First",
                      systemImage: viewModel.isProofCompleted ? "checkmark.circle.fill" : "lock.fill")
                    .font(viewModel.isProofCompleted ? .title2.bold() : .headline)
                    .frame(maxWidth: .infinity)
                    .padding(viewModel.isProofCompleted ? 20 : 16)
                    .background(viewModel.isProofCompleted ? Color.green : Color.gray.opacity(0.5))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .scaleEffect(stopButtonScale)
            }
            .disabled(!viewModel.isProofCompleted)
            .animation(.spring(response: 0.3), value: viewModel.isProofCompleted)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func startRingingTimer() {
        stopRingingTimer() // Clear any existing timer
        ringingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let startTime = viewModel.ringingStartTime {
                ringingSeconds = Int(Date().timeIntervalSince(startTime))
            }
        }
    }

    private func stopRingingTimer() {
        ringingTimer?.invalidate()
        ringingTimer = nil
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }
}

// MARK: - Wait Time Progress Row

struct WaitTimeProgressRow: View {
    let totalTime: Int
    let remainingTime: Int
    let isActive: Bool

    private var progress: Double {
        guard totalTime > 0 else { return 1.0 }
        return Double(totalTime - remainingTime) / Double(totalTime)
    }

    private var isComplete: Bool {
        remainingTime == 0 && isActive
    }

    var body: some View {
        HStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 30, height: 30)

                Circle()
                    .trim(from: 0, to: isActive ? progress : 0)
                    .stroke(isComplete ? Color.green : Color.cyan, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isComplete ? "Wait Complete" : (isActive ? "Waiting..." : "Take photo first"))
                    .font(.subheadline)
                    .foregroundStyle(.white)

                if isActive && !isComplete {
                    Text("\(remainingTime) seconds remaining")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Proof Status Row

struct ProofStatusRow: View {
    let icon: String
    let title: String
    let isComplete: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 30)

            Text(title)
                .font(.subheadline)

            Spacer()

            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? .green : .white.opacity(0.5))
        }
        .foregroundStyle(.white)
    }
}

#Preview {
    RingingView()
        .environment(ViewModel())
}
