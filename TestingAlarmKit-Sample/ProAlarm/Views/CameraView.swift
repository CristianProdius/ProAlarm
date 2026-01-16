//
//  CameraView.swift
//  ProAlarm
//
//  Camera view for capturing proof photos
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage?) -> Void

    @State private var capturedImage: UIImage?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isCameraReady = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                CameraPreviewView(
                    onCapture: { image in
                        capturedImage = image
                        onCapture(image)
                        dismiss()
                    },
                    onError: { error in
                        errorMessage = error
                        showError = true
                    },
                    onReady: {
                        withAnimation(.easeIn(duration: 0.3)) {
                            isCameraReady = true
                        }
                    }
                )
                .opacity(isCameraReady ? 1 : 0)

                // Loading indicator while camera initializes
                if !isCameraReady {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Starting camera...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .navigationTitle("Take Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCapture(nil)
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .alert("Camera Error", isPresented: $showError) {
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

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onError: (String) -> Void
    let onReady: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        controller.onError = onError
        controller.onReady = onReady
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// MARK: - Camera View Controller

class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?
    var onReady: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentCamera: AVCaptureDevice.Position = .front

    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        return button
    }()

    private lazy var switchCameraButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.onError?("Camera access was denied. Please enable it in Settings.")
                    }
                }
            }
        case .denied, .restricted:
            onError?("Camera access is required to take proof photos. Please enable it in Settings.")
        @unknown default:
            onError?("Unknown camera authorization status.")
        }
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let camera = getCamera(position: currentCamera),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            onError?("Unable to access camera.")
            return
        }

        photoOutput = AVCapturePhotoOutput()

        guard let captureSession = captureSession,
              let photoOutput = photoOutput,
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else {
            onError?("Unable to configure camera.")
            return
        }

        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.bounds

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }

        setupUI()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                self?.onReady?()
            }
        }
    }

    private func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func setupUI() {
        view.addSubview(captureButton)
        view.addSubview(switchCameraButton)

        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),

            switchCameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            switchCameraButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 50),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 50),
        ])

        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Take a photo drinking water"
        instructionLabel.textColor = .white
        instructionLabel.font = .systemFont(ofSize: 18, weight: .medium)
        instructionLabel.textAlignment = .center
        view.addSubview(instructionLabel)

        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
        ])
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()

        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
        }

        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    @objc private func switchCamera() {
        guard let captureSession = captureSession else { return }

        captureSession.beginConfiguration()

        // Remove current input
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }

        // Switch camera position
        currentCamera = currentCamera == .front ? .back : .front

        // Add new input
        guard let newCamera = getCamera(position: currentCamera),
              let newInput = try? AVCaptureDeviceInput(device: newCamera),
              captureSession.canAddInput(newInput) else {
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(newInput)
        captureSession.commitConfiguration()

        // Animate button rotation
        UIView.animate(withDuration: 0.3) {
            self.switchCameraButton.transform = self.switchCameraButton.transform.rotated(by: .pi)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            onError?("Failed to capture photo: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              var image = UIImage(data: imageData) else {
            onError?("Failed to process photo.")
            return
        }

        // Fix orientation for front camera
        if currentCamera == .front, let cgImage = image.cgImage {
            image = UIImage(cgImage: cgImage, scale: image.scale, orientation: .leftMirrored)
        }

        // Haptic feedback on capture
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        onCapture?(image)
    }
}

#Preview {
    CameraView { _ in }
}
