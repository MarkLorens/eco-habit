import SwiftUI

/// PRD §6.4, revised — shutter-first capture.
///
/// The camera no longer classifies while you point it. You compose, snap, and
/// the classifier runs once on the captured frame. Two flows from there:
/// confident match → logged on the spot; anything less → the "What Did You Do?"
/// picker (`CameraActionView`) seeded with today's unlogged habits.
struct VisualSearchView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()

    /// Above this similarity the top match logs without asking. Tune freely —
    /// the confident/unsure split hangs entirely on this number until the
    /// final condition logic is defined.
    private let confidenceThreshold: Float = 0.27

    private enum Overlay { case firstTimer, analyzing, whoops }

    @AppStorage("hasSeenCameraIntro") private var hasSeenIntro = false
    @State private var overlay: Overlay?
    @State private var pickerPhoto: UIImage?
    @State private var pickerSuggestions: [Habit] = []
    @State private var showingPicker = false

    /// Splashed over the viewfinder after a confident log: the mascot of the
    /// logged category, the practice it recognised, and what it paid.
    private struct PointsSplash {
        let mascot: String
        let habitName: String
        let points: String
    }
    @State private var pointsSplash: PointsSplash?

    var body: some View {
        ZStack {
            if showingPicker, let photo = pickerPhoto {
                CameraActionView(
                    photo: photo,
                    suggestions: pickerSuggestions,
                    onBack: { showingPicker = false },
                    onDone: { dismiss() }
                )
                .transition(.move(edge: .trailing))
            } else {
                cameraScreen
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingPicker)
        .task { await camera.start() }
        .onAppear { if !hasSeenIntro { overlay = .firstTimer } }
        .onDisappear { camera.stop() }
        .onChange(of: camera.snap) { _, result in
            guard let result else { return }
            camera.clearSnap()
            resolve(result)
        }
    }

    // MARK: - Camera screen

    private var cameraScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAvailable {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                placeholder
            }

            // Keeps the white title legible over a bright scene.
            LinearGradient(
                colors: [.black.opacity(0.45), .clear],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomBar
            }

            if let overlay { modal(overlay) }

            if let pointsSplash { splash(pointsSplash) }
        }
    }

    /// The score, right there on the viewfinder — the reward should land where
    /// the action happened, not as a toast on some other screen. Same card
    /// family as the other camera modals, so the mascot stays in character.
    private func splash(_ splash: PointsSplash) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: Tokens.Spacing.md) {
                Image(splash.mascot)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 76)

                Text("Nice one!")
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)

                Text(splash.habitName)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(splash.points)
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)
                    .padding(.horizontal, Tokens.Spacing.xxl)
                    .padding(.vertical, Tokens.Spacing.sm)
                    .background(Capsule().fill(Tokens.Palette.lime))
            }
            .padding(Tokens.Spacing.xxl)
            .frame(maxWidth: 300)
            .background(RoundedRectangle(cornerRadius: 20).fill(Tokens.Palette.white))
        }
        .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    private var topBar: some View {
        ZStack {
            VStack(spacing: Tokens.Spacing.xs) {
                Text("Take a Picture")
                    .textStyle(Tokens.Typography.title2)
                    .foregroundStyle(Tokens.Palette.white)
                Text("Log your action")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Palette.white.opacity(0.85))
            }

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Tokens.Palette.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.black.opacity(0.35)))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, Tokens.Spacing.xl)
        .padding(.top, Tokens.Spacing.sm)
    }

    private var bottomBar: some View {
        HStack {
            control(icon: camera.isTorchOn ? "bolt.fill" : "bolt.slash.fill") {
                camera.toggleTorch()
            }

            Spacer()

            Button { takeSnap() } label: {
                ZStack {
                    Circle()
                        .stroke(Tokens.Palette.white.opacity(0.55), lineWidth: 4)
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(Tokens.Palette.white)
                        .frame(width: 64, height: 64)
                }
            }
            .buttonStyle(.plain)
            .disabled(overlay != nil)

            Spacer()

            control(icon: "arrow.triangle.2.circlepath") {
                camera.flipCamera()
            }
        }
        .padding(.horizontal, 44)
        .padding(.bottom, Tokens.Spacing.goodLord)
    }

    /// Bare white glyphs, as in the design — no circles behind them.
    private func control(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Tokens.Palette.white)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Snap → two flows

    private func takeSnap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        overlay = .analyzing

        if camera.isAvailable {
            camera.requestSnapshot()
        } else {
            // No camera on the Simulator — a placeholder image keeps the whole
            // flow (analyzing → whoops → picker) testable end to end.
            Task {
                try? await Task.sleep(for: .seconds(0.6))
                resolve(SnapResult(image: Self.simulatorPhoto(), matches: []))
            }
        }
    }

    private func resolve(_ result: SnapResult) {
        Task {
            // Let "Wait a Minute…" read as a beat, not a flicker.
            try? await Task.sleep(for: .seconds(0.8))

            if let top = result.matches.first,
               top.similarity >= confidenceThreshold,
               let habit = MockData.habitsById[top.habitId],
               app.isAvailable(habit) {
                // Flow 1 — the photo is unambiguous: score it immediately,
                // splash the points over the viewfinder, then leave.
                let logged = app.logAndToast(habit, source: .visualSearch)
                overlay = nil
                let text: String
                switch logged {
                case .logged(let points): text = "+\(points) pts"
                case .foundation(let gain): text = "+\(gain) Vitality"
                default: text = habit.name
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
                    pointsSplash = PointsSplash(
                        mascot: habit.category.icon,
                        habitName: habit.name,
                        points: text
                    )
                }
                // A beat longer than the plain capsule was — there is a
                // practice name to read now.
                try? await Task.sleep(for: .seconds(1.8))
                dismiss()
            } else {
                // Flow 2 — not sure: own up, then hand over to the picker.
                pickerPhoto = result.image
                pickerSuggestions = suggestions(from: result.matches)
                overlay = .whoops
            }
        }
    }

    /// Classifier's best guesses first, topped up with other habits still
    /// available today so the picker never shows fewer than three options.
    private func suggestions(from matches: [HabitMatch]) -> [Habit] {
        var out = matches
            .compactMap { MockData.habitsById[$0.habitId] }
            .filter { app.isAvailable($0) }

        if out.count < 3 {
            let fill = MockData.habits.filter { habit in
                app.isAvailable(habit) && !out.contains(where: { $0.id == habit.id })
            }
            out += fill.prefix(3 - out.count)
        }
        return Array(out.prefix(3))
    }

    // MARK: - Modals

    private func modal(_ kind: Overlay) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: Tokens.Spacing.md) {
                Image(mascot(kind))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72)

                Text(title(kind))
                    .textStyle(Tokens.Typography.title)
                    .foregroundStyle(Tokens.Semantic.text)

                Text(message(kind))
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if kind != .analyzing {
                    Text("Tap Anywhere to Continue")
                        .textStyle(Tokens.Typography.footnote)
                        .foregroundStyle(Tokens.Semantic.footnote.opacity(0.6))
                        .padding(.top, Tokens.Spacing.xs)
                }
            }
            .padding(Tokens.Spacing.xxl)
            .frame(maxWidth: 300)
            .background(RoundedRectangle(cornerRadius: 20).fill(Tokens.Palette.white))
        }
        .contentShape(Rectangle())
        .onTapGesture { tapModal(kind) }
        .transition(.opacity)
    }

    private func tapModal(_ kind: Overlay) {
        switch kind {
        case .firstTimer:
            hasSeenIntro = true
            overlay = nil
        case .whoops:
            overlay = nil
            showingPicker = true
        case .analyzing:
            break   // nothing to skip to — the classifier decides where we go
        }
    }

    private func mascot(_ kind: Overlay) -> String {
        switch kind {
        // The pink "?!" mascot fronts both the intro and the miss, as designed.
        case .firstTimer, .whoops: return "mascot-whoops"
        case .analyzing: return "mascot-analyzing"
        }
    }

    private func title(_ kind: Overlay) -> String {
        switch kind {
        case .firstTimer: return "Show us what you did!"
        case .analyzing: return "Wait a Minute…"
        case .whoops: return "Whoops!"
        }
    }

    private func message(_ kind: Overlay) -> String {
        switch kind {
        case .firstTimer: return "Take a picture of your action and log it in seconds."
        case .analyzing: return "We're identifying your action.\nThis will only take a moment."
        case .whoops: return "We can't identify that but you can choose what you did and we'll log it for you!"
        }
    }

    // MARK: - Simulator

    private var placeholder: some View {
        VStack(spacing: Tokens.Spacing.md) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Tokens.Palette.white.opacity(0.5))
            Text(camera.permissionDenied
                 ? "Camera access is off.\nTurn it on in iOS Settings."
                 : "No camera on this device.\nThe shutter still walks the whole flow.")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Palette.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private static func simulatorPhoto() -> UIImage {
        let size = CGSize(width: 960, height: 720)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.35, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
