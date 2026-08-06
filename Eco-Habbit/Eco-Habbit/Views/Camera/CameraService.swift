import AVFoundation
import SwiftUI
import Combine

/// Minimal capture stack behind the design's custom camera UI. On the Simulator —
/// where there is no capture device — `isAvailable` stays false and the view falls
/// back to the designed placeholder, so the whole flow is still exercisable.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isRunning = false
    @Published var permissionDenied = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                permissionDenied = true
                return
            }
        default:
            permissionDenied = true
            return
        }

        guard configureIfNeeded() else { return }

        let session = self.session
        await Task.detached { session.startRunning() }.value
        isRunning = session.isRunning
    }

    func stop() {
        guard isConfigured else { return }
        let session = self.session
        Task.detached { session.stopRunning() }
        isRunning = false
    }

    /// Returns nil when there's no real camera — the caller then feeds the mock
    /// detector a nil image, which it already tolerates.
    func capturePhoto() async -> UIImage? {
        guard isAvailable, isRunning else { return nil }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return isAvailable }
        isConfigured = true

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ), let input = try? AVCaptureDeviceInput(device: device) else {
            isAvailable = false
            return false
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        isAvailable = true
        return true
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            captureContinuation?.resume(returning: image)
            captureContinuation = nil
        }
    }
}

/// Live preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
