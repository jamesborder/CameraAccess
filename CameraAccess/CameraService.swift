import AVFoundation
import Photos
import UIKit

enum CameraError: LocalizedError {
    case denied
    case restricted
    case setupFailed
    case captureFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .denied: return "Camera access denied. Please enable it in Settings."
        case .restricted: return "Camera access is restricted on this device."
        case .setupFailed: return "Failed to set up the camera."
        case .captureFailed: return "Failed to capture the photo."
        case .saveFailed: return "Failed to save the photo to your library."
        }
    }
}

class CameraService: NSObject, ObservableObject {
    @Published var error: CameraError?
    @Published var capturedImage: UIImage?
    @Published var isSaving = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.cameraaccess.session")

    func checkAuthorizationAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupSession()
                } else {
                    DispatchQueue.main.async { self.error = .denied }
                }
            }
        case .denied:
            DispatchQueue.main.async { self.error = .denied }
        case .restricted:
            DispatchQueue.main.async { self.error = .restricted }
        @unknown default:
            DispatchQueue.main.async { self.error = .setupFailed }
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: currentPosition
            ),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.error = .setupFailed }
                return
            }

            session.addInput(input)

            guard session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.error = .setupFailed }
                return
            }

            session.addOutput(photoOutput)
            session.commitConfiguration()

            start()
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: newPosition
            )

            guard let newDevice = discoverySession.devices.first,
                let newInput = try? AVCaptureDeviceInput(device: newDevice)
            else {
                DispatchQueue.main.async { self.error = .setupFailed }
                return
            }

            session.beginConfiguration()

            if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
                session.removeInput(currentInput)
            }

            if session.canAddInput(newInput) {
                session.addInput(newInput)
                DispatchQueue.main.async { self.currentPosition = newPosition }
            } else {
                DispatchQueue.main.async { self.error = .setupFailed }
            }

            session.commitConfiguration()
        }
    }

    func cycleFlashMode() {
        switch flashMode {
        case .off: flashMode = .on
        case .on: flashMode = .auto
        case .auto: flashMode = .off
        @unknown default: flashMode = .off
        }
    }

    private func saveToPhotoLibrary(_ imageData: Data) {
        DispatchQueue.main.async { self.isSaving = true }

        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performSave(imageData)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    self.performSave(imageData)
                } else {
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.error = .saveFailed
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.isSaving = false
                self.error = .saveFailed
            }
        }
    }

    private func performSave(_ imageData: Data) {
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: imageData, options: nil)
        } completionHandler: { success, _ in
            DispatchQueue.main.async {
                self.isSaving = false
                if !success {
                    self.error = .saveFailed
                }
            }
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if error != nil {
            DispatchQueue.main.async { self.error = .captureFailed }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.error = .captureFailed }
            return
        }

        DispatchQueue.main.async {
            self.capturedImage = UIImage(data: data)
        }

        saveToPhotoLibrary(data)
    }
}
