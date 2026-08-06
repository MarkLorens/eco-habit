import SwiftUI

/// Fullscreen capture flow: live → analyzing → result, with the category-correction
/// strip that auto-dismisses. Points are credited the moment the mock detector lands,
/// unless the detected activity was already logged today.
struct CameraCaptureView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()

    @State private var phase: Phase = .live
    @State private var capturedImage: UIImage?
    @State private var detected: Activity?
    @State private var awardedPoints = 0
    @State private var alreadyLogged = false
    @State private var showingCorrection = false
    @State private var correctionTask: Task<Void, Never>?

    private enum Phase { case live, analyzing, result }

    var body: some View {
        ZStack {
            Color(hex: 0x0B0B0C).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                viewfinder
                correctionStrip
                shutterRow
            }
        }
        .statusBarHidden()
        .task {
            await camera.start()
        }
        .onDisappear {
            correctionTask?.cancel()
            camera.stop()
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            CircleIconButton(
                systemName: "xmark",
                size: 36,
                background: .white.opacity(0.15),
                foreground: .white
            ) {
                dismiss()
            }
            Spacer()

            if phase == .live {
                Text(camera.isAvailable ? "Point at your action" : "Simulated capture")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x26292B), Color(hex: 0x0F1112)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            if camera.isAvailable, phase == .live {
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            if let capturedImage, phase != .live {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.45)))
            }

            switch phase {
            case .live:
                if !camera.isAvailable {
                    VStack(spacing: 8) {
                        Image(systemName: camera.permissionDenied ? "camera.metering.unknown" : "camera.viewfinder")
                            .font(.system(size: 32, weight: .light))
                            .foregroundStyle(.white.opacity(0.35))
                        Text(camera.permissionDenied
                             ? "Camera access is off. The shutter still runs a simulated detection."
                             : "Point at your action")
                            .font(Theme.F.body(13))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 240)
                    }
                }

            case .analyzing:
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text("Analyzing your action…")
                        .font(Theme.F.body(14))
                        .foregroundStyle(.white)
                }

            case .result:
                resultOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var resultOverlay: some View {
        if let detected {
            ZStack {
                if !alreadyLogged {
                    ConfettiBurst()
                }

                VStack(spacing: 8) {
                    if alreadyLogged {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.C.accent2_300)
                        Text("Already logged today")
                            .font(Theme.F.heading(24))
                            .foregroundStyle(.white)
                        Text("\(detected.name) is already on today's list — no double points.")
                            .font(Theme.F.body(13.5))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 250)
                    } else {
                        Text("+\(awardedPoints) pts")
                            .font(Theme.F.heading(44))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                        Text(detected.name)
                            .font(Theme.F.body(14.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

                    EHTag(text: detected.category.name, style: .accent)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 24)
            }
        }
    }

    @ViewBuilder
    private var correctionStrip: some View {
        if showingCorrection, let detected {
            VStack(alignment: .leading, spacing: 8) {
                Text("Not the right category? Tap to fix")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(.white)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(MockMLDetector.corrections(excluding: detected)) { alternative in
                            Button {
                                correct(to: alternative)
                            } label: {
                                Text(alternative.category.shortName)
                                    .font(Theme.F.body(12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(.white.opacity(0.15)))
                            }
                            .buttonStyle(PlainPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.12)))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var shutterRow: some View {
        HStack {
            switch phase {
            case .live:
                Button(action: capture) {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 4).padding(-4))
                }
                .buttonStyle(PlainPressStyle())
                .accessibilityLabel("Capture")

            case .analyzing:
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 70, height: 70)

            case .result:
                HStack(spacing: 12) {
                    Button("Snap another") { reset() }
                        .buttonStyle(SecondaryButtonStyle(height: 48, fontSize: 15))
                        .foregroundStyle(.white)
                    Button("Done") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle(height: 48, fontSize: 16))
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 34)
        .padding(.top, 4)
    }

    // MARK: Flow

    private func capture() {
        Task {
            let image = await camera.capturePhoto()
            capturedImage = image
            withAnimation(.easeInOut(duration: 0.2)) { phase = .analyzing }

            try? await Task.sleep(for: MockMLDetector.analysisDuration)

            let result = MockMLDetector.detect(in: image, favouring: app.favouriteCategories)
            apply(result.activity, image: image)
        }
    }

    private func apply(_ activity: Activity, image: UIImage?) {
        detected = activity

        switch app.logActivity(activity, source: .camera, evidenceImage: image) {
        case .awarded(let award):
            awardedPoints = award.points
            alreadyLogged = false
        case .alreadyDoneToday:
            awardedPoints = 0
            alreadyLogged = true
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            phase = .result
            showingCorrection = true
        }
        scheduleCorrectionDismiss()
    }

    private func correct(to alternative: Activity) {
        correctionTask?.cancel()
        withAnimation { showingCorrection = false }

        // Undo whatever the detector's first guess credited, then log the real one.
        if let previous = detected, !alreadyLogged {
            app.revertTodaysCompletion(activityId: previous.id)
        }
        apply(alternative, image: capturedImage)
    }

    private func scheduleCorrectionDismiss() {
        correctionTask?.cancel()
        correctionTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation { showingCorrection = false }
        }
    }

    private func reset() {
        correctionTask?.cancel()
        capturedImage = nil
        detected = nil
        awardedPoints = 0
        alreadyLogged = false
        showingCorrection = false
        withAnimation { phase = .live }
        Task { await camera.start() }
    }
}

// MARK: - Reward confetti

private struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let color: Color
        let delay: Double
        let duration: Double
    }

    @State private var fired = false

    private let pieces: [Piece] = [
        Piece(x: 0.20, y: 0.20, size: 8, color: Theme.C.accent400, delay: 0.00, duration: 1.1),
        Piece(x: 0.70, y: 0.15, size: 10, color: Theme.C.accent2_400, delay: 0.10, duration: 1.3),
        Piece(x: 0.45, y: 0.25, size: 7, color: .white, delay: 0.05, duration: 1.0),
        Piece(x: 0.35, y: 0.18, size: 9, color: Theme.C.accent300, delay: 0.15, duration: 1.2),
        Piece(x: 0.60, y: 0.22, size: 8, color: Theme.C.accent2_300, delay: 0.08, duration: 1.4),
        Piece(x: 0.80, y: 0.28, size: 7, color: Theme.C.accent200, delay: 0.20, duration: 1.15),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { piece in
                Circle()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .position(x: piece.x * geo.size.width, y: piece.y * geo.size.height)
                    .offset(y: fired ? 140 : 0)
                    .rotationEffect(.degrees(fired ? 280 : 0))
                    .opacity(fired ? 0 : 1)
                    .animation(
                        .easeOut(duration: piece.duration).delay(piece.delay),
                        value: fired
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { fired = true }
    }
}
