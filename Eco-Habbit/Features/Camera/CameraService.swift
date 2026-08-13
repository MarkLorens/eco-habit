import AVFoundation
import SwiftUI
import Combine

/// Capture stack for the camera screen.
///
/// **Shutter-driven, not continuous.** Frames stream for the live preview, but
/// the model only runs when the user presses the button. That is a deliberate
/// change from the always-on version: inference at 3 fps heated the phone to
/// keep a chip row updating that nobody was reading, and a deliberate press is
/// a much better signal of "I am pointing at the thing I mean".
///
/// **No photo is stored.** The frame is classified in memory and discarded —
/// nothing reaches disk, the photo library, or the network.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isRunning = false
    @Published var permissionDenied = false

    /// Nil until a shutter press resolves.
    @Published private(set) var verdict: CaptureVerdict?
    /// Everything the model scored — habits, the strongest distractor, and the
    /// winner's share of the field. Shown in the readout so a weak or wrong
    /// detection is visible rather than silent.
    @Published private(set) var lastFrame: RankedFrame = .empty
    @Published private(set) var isAnalysing = false
    @Published private(set) var classifierError: String?
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

        if let error = await processor.loadClassifier() {
            classifierError = error.localizedDescription
        } else {
            isReady = true
        }

        processor.onResult = { [weak self] frame, result in
            Task { @MainActor in
                self?.lastFrame = frame
                self?.verdict = result
                self?.isAnalysing = false
            }
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
        verdict = nil
        isAnalysing = false
    }

    /// The live thresholds, surfaced for the tuning readout so the numbers on
    /// screen are the ones actually in force rather than a copy that can drift.
    var minThreshold: Float { (try? HabitClassifier.shared.get())?.minSimilarity ?? 0.15 }
    var autoLogThreshold: Float { (try? HabitClassifier.shared.get())?.autoLogSimilarity ?? 0.30 }
    var confidenceThreshold: Float { (try? HabitClassifier.shared.get())?.autoLogConfidence ?? 0.55 }
    /// 0 means no distractors are bundled — regenerate `habit_vectors.json`.
    var distractorCount: Int { (try? HabitClassifier.shared.get())?.distractorCount ?? 0 }

    /// Classify the next frame. Resolves into `verdict`.
    func capture() {
        guard isReady, !isAnalysing else { return }
        isAnalysing = true
        verdict = nil
        processor.requestCapture()
    }

    /// Back to the viewfinder after a result.
    /// Back to a clean viewfinder — the verdict *and* the detection readout go,
    /// so what's on screen always belongs to the shot you just took.
    func reset() {
        verdict = nil
        lastFrame = .empty
        isAnalysing = false
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
        // 720p for a sharp preview; the encoder centre-crops to 256² anyway.
        session.sessionPreset = .hd1280x720
        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        // Small buffers: the crop throws the rest away, and 1080p BGRA at 30 fps
        // is ~250 MB/s of allocation felt as heat long before it is seen as lag.
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
/// been refilled with by then, which produces plausible results from the wrong
/// frame. Only the finished verdict crosses back.
///
/// This is also why the shutter sets a flag rather than grabbing a frame: the
/// next frame to arrive is classified where it is still alive.
private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    var onResult: (@Sendable (RankedFrame, CaptureVerdict) -> Void)?

    private var classifier: HabitClassifier?
    private let lock = NSLock()
    private var captureRequested = false

    func loadClassifier() async -> Error? {
        if classifier != nil { return nil }
        switch await Task.detached(priority: .userInitiated, operation: { HabitClassifier.shared }).value {
        case .success(let loaded):
            classifier = loaded
            return nil
        case .failure(let error):
            return error
        }
    }

    func requestCapture() {
        lock.lock()
        captureRequested = true
        lock.unlock()
    }

    private func consumeRequest() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard captureRequested else { return false }
        captureRequested = false
        return true
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard consumeRequest() else { return }
        guard let classifier, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // `.right` is the back camera's native landscape buffer seen in portrait.
        // Get this wrong and Vision reads a sideways image, which scores
        // wrong-but-plausible for everything.
        guard let frame = try? classifier.search(buffer, orientation: .right) else {
            onResult?(.empty, .nothing)
            return
        }
        onResult?(frame, classifier.verdict(for: frame))
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
