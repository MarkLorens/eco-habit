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
/// **No photo is stored.** The captured frame is classified and held in memory
/// for the picker screen only — nothing reaches disk, the photo library, or
/// the network.
@MainActor
final class CameraService: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isRunning = false
    @Published var permissionDenied = false

    /// Nil until a shutter press resolves.
    @Published private(set) var verdict: CaptureVerdict?
    /// Everything the model scored — habits, the strongest distractor, and the
    /// winner's share of the field.
    @Published private(set) var lastFrame: RankedFrame = .empty
    /// The frame the verdict was made from, so the "What Did You Do?" screen
    /// can show what the user actually photographed. Memory only.
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var isAnalysing = false
    @Published private(set) var classifierError: String?
    @Published private(set) var isReady = false

    @Published private(set) var isTorchOn = false
    @Published private(set) var position: AVCaptureDevice.Position = .back

    /// A Fight check-in code seen in the viewfinder, already unwrapped from its
    /// `ecohabit://fight/` payload. Cleared by `rearmScanner()`.
    ///
    /// Unlike the habit classifier this runs **continuously** — QR detection is
    /// hardware-accelerated and effectively free, and a code is either in frame
    /// or it is not, so there is nothing for a shutter press to disambiguate.
    @Published private(set) var scannedFightCode: String?

    let session = AVCaptureSession()

    private let videoOutput = AVCaptureVideoDataOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let frameQueue = DispatchQueue(label: "eco.camera.frames", qos: .userInitiated)
    private let processor = FrameProcessor()
    private var isConfigured = false
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var isScannerArmed = true

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

        processor.onResult = { [weak self] image, frame, result in
            Task { @MainActor in
                guard let self else { return }
                self.setFrameDelivery(false)
                self.capturedImage = image
                self.lastFrame = frame
                self.verdict = result
                self.isAnalysing = false
            }
        }

        guard configureIfNeeded() else { return }

        let session = self.session
        await Task.detached { session.startRunning() }.value
        isRunning = session.isRunning
    }

    func stop() {
        guard isConfigured else { return }
        if isTorchOn { toggleTorch() }
        setFrameDelivery(false)
        let session = self.session
        Task.detached { session.stopRunning() }
        isRunning = false
        verdict = nil
        capturedImage = nil
        isAnalysing = false
    }

    /// The live thresholds, surfaced for the tuning readout so the numbers on
    /// screen are the ones actually in force rather than a copy that can drift.
    var minThreshold: Float { (try? HabitClassifier.shared.get())?.minSimilarity ?? 0.15 }
    var autoLogThreshold: Float { (try? HabitClassifier.shared.get())?.autoLogSimilarity ?? 0.30 }
    var confidenceThreshold: Float { (try? HabitClassifier.shared.get())?.autoLogConfidence ?? 0.55 }
    /// 0 means no distractors are bundled — regenerate `habit_vectors.json`.
    var distractorCount: Int { (try? HabitClassifier.shared.get())?.distractorCount ?? 0 }

    /// Frames only flow while a capture is in flight.
    private func setFrameDelivery(_ on: Bool) {
        videoOutput.connection(with: .video)?.isEnabled = on
    }

    /// Classify the next frame. Resolves into `verdict`.
    func capture() {
        guard isReady, !isAnalysing else { return }
        isAnalysing = true
        verdict = nil
        capturedImage = nil
        // Order matters: arm the processor only once frames can actually arrive,
        // or the request sits unconsumed and the shutter appears to hang.
        setFrameDelivery(true)
        processor.requestCapture()
    }

    /// Back to a clean viewfinder — the verdict, the captured frame *and* the
    /// detection readout go, so what's on screen always belongs to the shot you
    /// just took.
    func reset() {
        // Covers the abandoned-capture case: a shutter press that never resolved
        // because the view was dismissed would otherwise leave frames flowing.
        setFrameDelivery(false)
        verdict = nil
        lastFrame = .empty
        capturedImage = nil
        isAnalysing = false
    }

    /// Ready to read the next code.
    ///
    /// Needed because a QR held in frame is re-reported on every metadata
    /// callback; without disarming, one poster would fire check-in dozens of
    /// times a second.
    func rearmScanner() {
        scannedFightCode = nil
        isScannerArmed = true
    }

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
        processor.setOrientation(newPosition == .front ? .leftMirrored : .right)
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
        // 720p for a sharp preview; the encoder centre-crops to 256² anyway.
        session.sessionPreset = .hd1280x720
        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        // 960×540: big enough that the captured photo survives being shown as
        // the hero image on the picker screen, small enough to stay cheap —
        // frames only flow while a capture is in flight anyway.
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 960,
            kCVPixelBufferHeightKey as String: 540,
        ]
        videoOutput.setSampleBufferDelegate(processor, queue: frameQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        // Idle until the shutter. The viewfinder is an `AVCaptureVideoPreviewLayer`
        // reading the session directly, so this output feeds nothing on screen —
        // it exists only to hand one frame to the classifier.
        //
        // `isEnabled` stops delivery without begin/commitConfiguration, so there
        // is no reconfiguration stall and the preview never flickers.
        setFrameDelivery(false)

        // QR rides the same session as the frame stream — no second capture
        // stack, nothing to tear down when switching between the two jobs.
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
            // MUST come after `addOutput`. Before it, `.qr` is not yet an
            // available type and the assignment silently does nothing — the
            // camera then runs perfectly and never sees a single code.
            metadataOutput.metadataObjectTypes = [.qr]
        }

        session.commitConfiguration()

        isAvailable = true
        return true
    }
}

/// Owns the classifier and runs it **on the capture queue, inside the delegate
/// call** — a `CVPixelBuffer` is only valid until the delegate returns.
///
/// That placement is load-bearing. AVFoundation recycles the buffer immediately
/// after the delegate returns; handing it to a `Task { @MainActor }` and
/// classifying there reads whatever the buffer has been refilled with by then,
/// which produces plausible results from the wrong frame. Only the finished
/// verdict (and a copied-out UIImage) crosses back.
///
/// This is also why the shutter sets a flag rather than grabbing a frame: the
/// next frame to arrive is classified where it is still alive.
private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    var onResult: (@Sendable (UIImage?, RankedFrame, CaptureVerdict) -> Void)?

    private var classifier: HabitClassifier?
    private let lock = NSLock()
    private var captureRequested = false
    /// `.right` is the back camera's native landscape buffer seen in portrait.
    private var orientation: CGImagePropertyOrientation = .right
    private let ciContext = CIContext()

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

    func setOrientation(_ new: CGImagePropertyOrientation) {
        lock.lock()
        orientation = new
        lock.unlock()
    }

    private func consumeRequest() -> (requested: Bool, orientation: CGImagePropertyOrientation) {
        lock.lock()
        defer { lock.unlock() }
        guard captureRequested else { return (false, orientation) }
        captureRequested = false
        return (true, orientation)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let (requested, orientation) = consumeRequest()
        guard requested else { return }
        guard let classifier, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Copy the frame out as a UIImage while the buffer is still alive, so
        // the picker screen can show what was actually photographed.
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let image = ciContext.createCGImage(ciImage, from: ciImage.extent).map {
            UIImage(cgImage: $0, scale: 1,
                    orientation: orientation == .leftMirrored ? .leftMirrored : .right)
        }

        // Get the orientation wrong and Vision reads a sideways image, which
        // scores wrong-but-plausible for everything.
        guard let frame = try? classifier.search(buffer, orientation: orientation) else {
            onResult?(image, .empty, .nothing)
            return
        }
        onResult?(image, frame, classifier.verdict(for: frame))
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

// MARK: - QR

extension CameraService: AVCaptureMetadataOutputObjectsDelegate {

    /// Reports only codes carrying this app's scheme.
    ///
    /// Everything else — a wifi QR, a restaurant menu, a payment code — is
    /// dropped here without a toast or any visible reaction. The camera is a
    /// habit scanner most of the time, and interrupting that to say "this is not
    /// a Fight" about a poster nobody was pointing at would be noise.
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let payloads = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap(\.stringValue)

        MainActor.assumeIsolated {
            guard isScannerArmed,
                  let code = payloads.lazy.compactMap(Fight.code(fromPayload:)).first
            else { return }

            isScannerArmed = false
            scannedFightCode = code
        }
    }
}
