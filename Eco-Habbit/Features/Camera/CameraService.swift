import AVFoundation
import SwiftUI
import Combine

/// Capture stack for the visual-search viewfinder (PRD §5.3).
///
/// There is no photo output and no shutter — nothing is ever captured. Frames go
/// to a video data output, get classified in memory, and are discarded (§5.1).
/// On the Simulator there is no capture device, so `isAvailable` stays false and
/// the view shows its placeholder.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isRunning = false
    @Published var permissionDenied = false

    /// Latest ranked matches, replaced wholesale each inference pass.
    @Published private(set) var matches: [HabitMatch] = []
    @Published private(set) var classifierError: String?
    /// False until the model is loaded, so the viewfinder can say "warming up"
    /// rather than sit there showing nothing and looking broken.
    @Published private(set) var isReady = false

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameQueue = DispatchQueue(label: "eco.camera.frames", qos: .userInitiated)
    private let processor = FrameProcessor()
    private var isConfigured = false

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

        processor.onResults = { [weak self] results in
            Task { @MainActor in self?.matches = results }
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
        matches = []
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
        // 720p, not 1080p or .photo. The preview layer needs to look sharp, but
        // 1080p BGRA is 8.3 MB a frame — at 30 fps that is ~250 MB/s allocated,
        // copied and thrown away, which is felt as heat long before it is seen
        // as lag.
        session.sessionPreset = .hd1280x720
        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        // Ask the capture pipeline to hand us small buffers rather than scaling
        // 720p down inside Vision on every pass. The encoder centre-crops to
        // 256², so 480x270 loses nothing that survives the crop anyway.
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 480,
            kCVPixelBufferHeightKey as String: 270,
        ]
        videoOutput.setSampleBufferDelegate(processor, queue: frameQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()

        isAvailable = true
        return true
    }
}

/// Owns the classifier and runs it **on the capture queue, inside the delegate
/// call**.
///
/// That placement is load-bearing. A `CVPixelBuffer` is only valid until the
/// delegate returns — AVFoundation recycles it immediately after. Handing it to
/// a `Task { @MainActor }` and classifying there reads whatever the buffer has
/// been refilled with by the time the task is scheduled, which produces
/// plausible results from the wrong frame. Only the finished array crosses back.
private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// PRD §5.3 — target ~3 fps, tuned for thermals. Inference on every frame
    /// would heat the phone and buy nothing: chips cannot usefully change 30
    /// times a second, and a hand does not move that fast.
    private let interval: TimeInterval = 1.0 / 3.0

    /// Called on the capture queue with the finished ranking.
    var onResults: (@Sendable ([HabitMatch]) -> Void)?

    private var classifier: HabitClassifier?
    private var lastInferenceAt: TimeInterval = 0

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
        let now = CACurrentMediaTime()
        guard now - lastInferenceAt >= interval else { return }
        guard let classifier, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastInferenceAt = now

        // `.right` is the back camera's native landscape buffer seen in portrait.
        // Get this wrong and Vision feeds the encoder a sideways image, which
        // scores wrong-but-plausible for everything.
        // `search` now returns a whole ranked frame — habits, the strongest
        // distractor, and the winner's share of the field. The camera screen
        // still only consumes the habit list; the rest arrives with the view
        // work, so this takes the one field it already knew about.
        guard let frame = try? classifier.search(buffer, orientation: .right) else { return }
        onResults?(frame.habits)
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
