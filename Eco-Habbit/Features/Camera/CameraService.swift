import AVFoundation
import SwiftUI
import Combine

/// One shutter press: the captured frame and what the classifier made of it.
struct SnapResult: Equatable {
    let image: UIImage
    let matches: [HabitMatch]
}

/// Capture stack for the camera flow (PRD §5.3, revised).
///
/// The viewfinder no longer classifies continuously — frames flow to the video
/// output untouched until the shutter is pressed, then exactly one frame is
/// classified and returned as a `SnapResult`. Nothing is written to disk (§5.1).
/// On the Simulator there is no capture device, so `isAvailable` stays false and
/// the view drives the same flow with a placeholder image.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isRunning = false
    @Published var permissionDenied = false

    /// Set once per shutter press; the view reads it and calls `clearSnap()`.
    @Published private(set) var snap: SnapResult?
    @Published private(set) var classifierError: String?
    /// False until the model is loaded, so the shutter can wait for a model
    /// that is actually ready rather than silently classifying with nothing.
    @Published private(set) var isReady = false

    @Published private(set) var isTorchOn = false
    @Published private(set) var position: AVCaptureDevice.Position = .back

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "eco.camera.frames", qos: .userInitiated)
    private let processor = FrameProcessor()
    private var isConfigured = false
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
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

        // Loads on first use only — `HabitClassifier.shared` is a `static let`,
        // so reopening the camera reuses the model instead of re-reading 68 MB.
        if let error = await processor.loadClassifier() {
            classifierError = error.localizedDescription
        } else {
            isReady = true
        }

        processor.onSnapshot = { [weak self] result in
            Task { @MainActor in self?.snap = result }
        }

        guard configureIfNeeded() else { return }

        let session = self.session
        await Task.detached { session.startRunning() }.value
        isRunning = session.isRunning
    }

    func stop() {
        guard isConfigured else { return }
        if isTorchOn { toggleTorch() }
        let session = self.session
        Task.detached { session.stopRunning() }
        isRunning = false
        snap = nil
    }

    /// The next frame off the capture queue gets classified and delivered
    /// through `snap`.
    func requestSnapshot() {
        let processor = self.processor
        frameQueue.async { processor.snapshotRequested = true }
    }

    func clearSnap() { snap = nil }

    /// Torch, not true flash — the light stays on while composing, which is
    /// what a viewfinder-based capture can actually honour.
    func toggleTorch() {
        guard let device, device.hasTorch else { return }
        guard (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = isTorchOn ? .off : .on
        device.unlockForConfiguration()
        isTorchOn.toggle()
    }

    func flipCamera() {
        guard isConfigured, isAvailable else { return }
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        guard let newDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: newPosition
        ), let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }

        session.beginConfiguration()
        if let input { session.removeInput(input) }
        guard session.canAddInput(newInput) else {
            if let input { session.addInput(input) }
            session.commitConfiguration()
            return
        }
        session.addInput(newInput)
        session.commitConfiguration()

        device = newDevice
        input = newInput
        position = newPosition
        isTorchOn = false

        // The front camera's buffer is mirrored; the classifier needs to know.
        let processor = self.processor
        let orientation: CGImagePropertyOrientation = newPosition == .front ? .leftMirrored : .right
        frameQueue.async { processor.orientation = orientation }
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
        self.device = device
        self.input = input

        session.beginConfiguration()
        // 720p, not 1080p or .photo — the preview needs to look sharp without
        // the heat of shuttling full-resolution BGRA frames around.
        session.sessionPreset = .hd1280x720
        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        // 960×540: big enough that the captured photo survives being shown as
        // the hero image on the results screen, small enough to stay cheap.
        // Nothing is classified per-frame anymore, so this is copy cost only.
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 960,
            kCVPixelBufferHeightKey as String: 540,
        ]
        videoOutput.setSampleBufferDelegate(processor, queue: frameQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()

        isAvailable = true
        return true
    }
}

/// Owns the classifier and runs it **on the capture queue, inside the delegate
/// call** — a `CVPixelBuffer` is only valid until the delegate returns.
///
/// All mutable state here lives on the capture queue: `snapshotRequested` and
/// `orientation` are only ever touched via `frameQueue.async`.
private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Armed by the shutter; consumed by the next frame.
    var snapshotRequested = false
    /// `.right` is the back camera's native landscape buffer seen in portrait.
    var orientation: CGImagePropertyOrientation = .right

    /// Called on the capture queue with the finished capture.
    var onSnapshot: (@Sendable (SnapResult) -> Void)?

    private var classifier: HabitClassifier?
    private let ciContext = CIContext()

    /// Returns the failure, if there was one. Off the main actor because the
    /// very first call in a process is where the model actually loads.
    func loadClassifier() async -> Error? {
        if classifier != nil { return nil }

        let result = await Task.detached(priority: .userInitiated) {
            HabitClassifier.shared
        }.value

        switch result {
        case .success(let loaded):
            classifier = loaded
            return nil
        case .failure(let error):
            return error
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Detection happens per shutter press now — untouched frames just pass by.
        guard snapshotRequested else { return }
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        snapshotRequested = false

        var matches: [HabitMatch] = []
        if let classifier, let results = try? classifier.search(buffer, orientation: orientation) {
            matches = results
        }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let imageOrientation: UIImage.Orientation = orientation == .leftMirrored ? .leftMirrored : .right
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: imageOrientation)

        onSnapshot?(SnapResult(image: image, matches: matches))
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
