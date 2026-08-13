import AVFoundation
import SwiftUI
// The project sets SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY, so SwiftUI
// no longer re-exports Combine — ObservableObject needs it named directly.
import Combine

/// The attendee pointing their camera at the organiser's code.
///
/// The scanner knows which Fight it was opened from, so a scanned string only has
/// to match that Fight's `checkInCode` — there is nothing to parse and no token
/// format to keep in sync between two devices.
struct CheckInScannerView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let fight: Fight

    @StateObject private var scanner = QRScanner()
    @State private var feedback: Feedback?

    private struct Feedback: Equatable {
        let message: String
        let good: Bool
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if scanner.isAvailable {
                CameraPreview(session: scanner.session).ignoresSafeArea()
            } else {
                VStack(spacing: Theme.S.x3) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(scanner.permissionDenied
                         ? "Camera access is off.\nTurn it on in iOS Settings."
                         : "No camera on this device.\nType the code instead.")
                        .font(Theme.F.body(14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }

            reticle

            VStack {
                header
                Spacer()
                if let feedback { banner(feedback) }
                hint
            }
        }
        .task { await scanner.start() }
        .onDisappear { scanner.stop() }
        .onChange(of: scanner.lastCode) { _, code in
            guard let code else { return }
            Task { await handle(code) }
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            Spacer()
            Text(fight.title)
                .font(Theme.F.body(13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.black.opacity(0.35)))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Theme.S.x4)
        .padding(.top, Theme.S.x2)
    }

    private var reticle: some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(.white.opacity(0.85), lineWidth: 3)
            .frame(width: 240, height: 240)
    }

    private func banner(_ feedback: Feedback) -> some View {
        Label(feedback.message, systemImage: feedback.good ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(Theme.F.body(15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(feedback.good ? Theme.C.accent2_600 : Theme.C.accent600))
            .padding(.bottom, Theme.S.x2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var hint: some View {
        Text("Point at the code the organiser is showing")
            .font(Theme.F.body(13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.vertical, Theme.S.x4)
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.4))
    }

    // MARK: - Scanning

    private func handle(_ code: String) async {
        let result = await app.checkIn(to: fight, code: code)

        let feedback: Feedback = switch result {
        case .checkedIn(let points, _, let badge):
            Feedback(message: badge.map { "+\(points) pts · \($0.name)" } ?? "Checked in · +\(points) pts",
                     good: true)
        case .wrongCode: Feedback(message: "That code isn't for this Fight", good: false)
        case .alreadyCheckedIn: Feedback(message: "Already checked in", good: false)
        case .windowClosed: Feedback(message: "Check-in isn't open yet", good: false)
        case .eventCancelled: Feedback(message: "This Fight is cancelled", good: false)
        }

        withAnimation(.spring(response: 0.3)) { self.feedback = feedback }
        UINotificationFeedbackGenerator().notificationOccurred(feedback.good ? .success : .warning)

        // A successful check-in is terminal — there is nothing to scan twice.
        if feedback.good {
            try? await Task.sleep(for: .seconds(1.4))
            dismiss()
            return
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if self.feedback == feedback { self.feedback = nil } }
            scanner.rearm()
        }
    }
}

/// Metadata-output QR reader. Separate from `CameraService` — that one runs
/// Core ML on a frame stream, this one only needs AVFoundation's built-in
/// detector, which is far cheaper.
@MainActor
final class QRScanner: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published var permissionDenied = false
    /// Set once per scan, then cleared by `rearm()` — otherwise one code held in
    /// frame fires continuously.
    @Published private(set) var lastCode: String?

    let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private var isConfigured = false
    private var isArmed = true

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
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
    }

    func stop() {
        guard isConfigured else { return }
        let session = self.session
        Task.detached { session.stopRunning() }
    }

    func rearm() {
        lastCode = nil
        isArmed = true
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return isAvailable }
        isConfigured = true

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            isAvailable = false
            return false
        }

        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) {
            session.addOutput(output)
            // Must be set *after* adding the output, or the type isn't available yet.
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()

        isAvailable = true
        return true
    }
}

extension QRScanner: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let codes = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap(\.stringValue)

        MainActor.assumeIsolated {
            guard isArmed, let code = codes.first else { return }
            isArmed = false
            lastCode = code
        }
    }
}
