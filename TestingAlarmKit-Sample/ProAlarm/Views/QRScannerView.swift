//
//  QRScannerView.swift
//  ProAlarm
//
//  QR code scanner view for proof verification
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let expectedCode: String?
    let onCodeScanned: (String) -> Void

    @State private var scannedCode: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isValidCode = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                QRScannerPreviewView(
                    expectedCode: expectedCode,
                    onCodeScanned: { code in
                        scannedCode = code

                        // Validate code
                        if expectedCode == nil || code == expectedCode {
                            isValidCode = true
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)

                            // Delay dismissal for feedback
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onCodeScanned(code)
                            }
                        } else {
                            isValidCode = false
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                        }
                    },
                    onError: { error in
                        errorMessage = error
                        showError = true
                    }
                )

                // Scan frame overlay
                VStack {
                    Spacer()

                    ZStack {
                        // Corner markers
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isValidCode ? Color.green : Color.white, lineWidth: 3)
                            .frame(width: 250, height: 250)

                        if isValidCode {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    // Instructions
                    VStack(spacing: 10) {
                        Text(isValidCode ? "QR Code Verified!" : "Scan the QR code near your sink")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if let scanned = scannedCode, !isValidCode {
                            Text("Invalid QR code")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Scanner Error", isPresented: $showError) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - QR Scanner Preview View

struct QRScannerPreviewView: UIViewControllerRepresentable {
    let expectedCode: String?
    let onCodeScanned: (String) -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.expectedCode = expectedCode
        controller.onCodeScanned = onCodeScanned
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

// MARK: - QR Scanner View Controller

class QRScannerViewController: UIViewController {
    var expectedCode: String?
    var onCodeScanned: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupScanner()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupScanner()
                    } else {
                        self?.onError?("Camera access was denied.")
                    }
                }
            }
        case .denied, .restricted:
            onError?("Camera access is required to scan QR codes.")
        @unknown default:
            onError?("Unknown camera authorization status.")
        }
    }

    private func setupScanner() {
        captureSession = AVCaptureSession()

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              let captureSession = captureSession,
              captureSession.canAddInput(input) else {
            onError?("Unable to access camera.")
            return
        }

        captureSession.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            onError?("Unable to configure QR scanner.")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let stringValue = metadataObject.stringValue else {
            return
        }

        hasScanned = true
        captureSession?.stopRunning()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        onCodeScanned?(stringValue)
    }
}

#Preview {
    QRScannerView(expectedCode: nil) { _ in }
}
