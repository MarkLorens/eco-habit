import SwiftUI

/// Point, shoot, and either it logs itself or it asks.
///
/// The verdict comes from `HabitClassifier`: a `.confident` direct match logs
/// and celebrates on the spot; `.unsure`, `.nothing` and `.rejected` hand over
/// to the "What Did You Do?" picker (`CameraActionView`) seeded with today's
/// unlogged habits. The camera also reads Fight check-in QRs continuously —
/// a code in frame checks the user in without a shutter press.
///
/// **No photo is stored.** The frame is classified in memory; the picker shows
/// it and lets it go.
struct VisualSearchView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()

    private enum Overlay: Equatable {
        case firstTimer, analyzing, whoops
        /// A distractor outranked every habit — the model is fairly sure it is looking
        /// at a NON-habit, and says which. Distinct from `whoops`, which means it could
        /// not tell at all.
        case rejected(String)
    }

    @AppStorage("hasSeenCameraIntro") private var hasSeenIntro = false
    @State private var overlay: Overlay?
    @State private var pickerPhoto: UIImage?
    @State private var pickerSuggestions: [Habit] = []

    /// Whether the classifier had a plausible guess, as opposed to nothing at all.
    /// Set beside `pickerSuggestions` at every assignment so the two cannot drift.
    @State private var sawSomething = false
    @State private var showingPicker = false

    /// What the reward animation should show. Set by a logged habit or by a
    /// Fight check-in — the overlay does not care which.
    private struct Reward {
        let icon: Image
        let title: String
        let points: Int
        let tint: Color
        var badgeName: String?
        /// A Fight is a discrete errand, so the camera closes afterwards; an
        /// habit is one of many, so it stays open for the next one.
        var closesCamera: Bool
    }

    @State private var award: Reward?
    @State private var showAward = false

    /// The last code that failed, so holding it in frame does not re-report.
    @State private var lastRejectedCode: String?

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
        .onChange(of: camera.scannedFightCode) { _, code in
            guard let code else { return }
            checkIn(withCode: code)
        }
        .onChange(of: camera.verdict) { _, verdict in
            guard let verdict else { return }
            resolve(verdict)
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

            // `ToastLayer` also lives in `RootView`, but a `fullScreenCover`
            // presents in its own layer *above* the presenting view's overlays —
            // so every message raised in here (check-in windows, rejections)
            // would render behind the camera. It needs its own copy.
            ToastLayer()

            #if DEBUG
            // Compiled out of Release entirely. Everything the verdict was made from,
            // so a wrong answer can be read rather than guessed at.
            diagnostics
            #endif

            if let overlay { modal(overlay) }

            if showAward, let award {
                AwardOverlay(icon: award.icon,
                             title: award.title,
                             points: award.points,
                             tint: award.tint,
                             badgeName: award.badgeName,
                             onFinished: { awardFinished(closesCamera: award.closesCamera) })
            }
        }
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
            .disabled(overlay == .analyzing || showAward
                      || (camera.isAvailable && (!camera.isReady || camera.isAnalysing)))

            Spacer()

            control(icon: "arrow.triangle.2.circlepath") {
                camera.flipCamera()
            }
        }
        .padding(.horizontal, 44)
        .padding(.bottom, Tokens.Spacing.goodLord)
    }

    #if DEBUG
    /// The numbers behind the last verdict.
    ///
    /// The thresholds shown are read live from the classifier rather than copied, so
    /// they cannot drift from the ones actually deciding — and `explain` lives beside
    /// the gates for the same reason.
    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verdictLabel)
                .foregroundStyle(Tokens.Palette.lime)
            Text(camera.lastExplanation)
                .foregroundStyle(.white.opacity(0.75))

            Text(String(format: "conf %.2f · floor %.2f · auto %.2f/%.2f · %d distractors",
                        camera.lastFrame.confidence, camera.minThreshold,
                        camera.autoLogThreshold, camera.confidenceThreshold,
                        camera.distractorCount))
                .foregroundStyle(.white.opacity(0.55))

            ForEach(Array(camera.lastFrame.habits.enumerated()), id: \.element.habitId) { i, m in
                Text(String(format: "%d %-30@ %.3f", i + 1, m.habitId as NSString, m.similarity))
                    .foregroundStyle(.white.opacity(i == 0 ? 0.95 : 0.6))
            }
            if let d = camera.lastFrame.topDistractor {
                Text(String(format: "✕ %-30@ %.3f", d.label as NSString, d.similarity))
                    .foregroundStyle(Tokens.Palette.orange.opacity(0.9))
            }
        }
        .font(.system(size: 9, design: .monospaced))
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.55)))
        .padding(.horizontal, Tokens.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.bottom, 150)
        .allowsHitTesting(false)
    }

    private var verdictLabel: String {
        switch camera.verdict {
        case .confident(let m):  "CONFIDENT \(m.habitId) — auto-logged"
        case .unsure(let m):     "UNSURE (\(m.count)) — picker"
        case .rejected(let d):   "REJECTED \(d.label)"
        case .nothing:           "NOTHING"
        case nil:                "— take a shot —"
        }
    }
    #endif

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
            camera.capture()
        } else {
            // No camera on the Simulator — a placeholder image keeps the whole
            // flow (analyzing → whoops → picker) testable end to end.
            Task {
                try? await Task.sleep(for: .seconds(0.6))
                overlay = nil
                pickerPhoto = Self.simulatorPhoto()
                pickerSuggestions = suggestions(from: [])
                sawSomething = false
                overlay = .whoops
            }
        }
    }

    private func resolve(_ verdict: CaptureVerdict) {
        let photo = camera.capturedImage
        Task {
            // Let "Wait a Minute…" read as a beat, not a flicker.
            try? await Task.sleep(for: .seconds(0.6))
            overlay = nil

            switch verdict {
            case .confident(let match):
                // Flow 1 — the photo is unambiguous: score it immediately.
                if let habit = MockData.habitsById[match.habitId] {
                    log(habit)
                } else {
                    camera.reset()
                }

            case .unsure(let matches):
                // Flow 2 — plausible candidates: own up, then let the user pick.
                pickerPhoto = photo ?? Self.simulatorPhoto()
                pickerSuggestions = suggestions(from: matches)
                sawSomething = true
                overlay = .whoops

            case .rejected(let distractor):
                // The model identified something and refused it. Saying "we can't
                // identify that" here would be a lie, and sending the user to a picker
                // of unrelated habits trains them to log whatever is nearest.
                overlay = .rejected(distractor.label)

            case .nothing:
                // Genuinely could not tell. There are no camera matches to offer, so
                // recommendations are all that is left.
                pickerPhoto = photo ?? Self.simulatorPhoto()
                pickerSuggestions = suggestions(from: [])
                sawSomething = false
                overlay = .whoops
            }
        }
    }

    /// What the camera saw first, then what the user is most likely to want.
    ///
    /// **The top-up used to be `MockData.habits`, which is bundle order.** That meant a
    /// failed detection offered the first three lines of `habits.json` — reusable bottle,
    /// shopping bag, refuse cutlery — identically, to every user, every time, out of 38.
    /// All three are `food_*`, so photographing a bike got you three food actions.
    ///
    /// `suggestedHabits` is the dashboard's own recommendation: still available today,
    /// favourite categories first. With no matches this returns pure recommendations,
    /// which is the honest answer when the model saw nothing.
    ///
    /// Still padded to three rather than showing one lonely real match: `CameraActionView`
    /// has no "something else" route, only back-to-camera, so a short list is a dead end
    /// for anyone whose action was not recognised. Which situation the user is in is
    /// carried by the overlay copy instead.
    private func suggestions(from matches: [HabitMatch]) -> [Habit] {
        let detected = matches
            .compactMap { MockData.habitsById[$0.habitId] }
            .filter { app.isAvailable($0) }

        // **Camera matches are never padded.** They used to be topped up to three from
        // `suggestedHabits`, so one real match arrived flanked by two the camera never
        // saw, indistinguishable from it — which is worse than offering fewer.
        guard detected.isEmpty else { return Array(detected.prefix(3)) }

        // Nothing was recognised, so recommendations are all there is.
        return Array(app.suggestedHabits.prefix(3))
    }

    // MARK: - Logging

    private func log(_ habit: Habit) {
        // `.visualSearch` is what marks the log as photo-evidence; it is what
        // the evidence badges count.
        // `announcesSuccess: false` — `AwardOverlay` below already names the habit and
        // counts up its points, so the success toast was the same sentence twice.
        let result = app.logAndToast(habit, source: .visualSearch, announcesSuccess: false)

        // Keep the frame that earned it. After the log, not before — the file is named
        // after the log's own id, so there is nothing to name it until it exists.
        // Saved even at the daily cap and on the early return below: the action happened
        // and the picture is the evidence, whether or not it paid points.
        if result.succeeded, let photo = camera.capturedImage {
            app.saveEvidence(photo, for: habit.id)
        }

        // `atDailyCap` gets the same treatment as a refusal *for the overlay
        // only* — the log itself has already landed and still counts. The
        // overlay counts up to `points`, so at the cap it would run the whole
        // celebration to arrive at "+0".
        guard case .logged(let points, let atDailyCap) = result, !atDailyCap else {
            camera.reset()
            return
        }
        award = Reward(
            icon: Image(habit.category.mascotName),
            title: habit.name,
            points: points,
            tint: habit.category.accentColor,
            badgeName: app.data.earnedBadges.last?.name,
            closesCamera: false
        )
        // No transition animation here. The overlay runs its own timeline and
        // takes itself away; wrapping it in one would fight that.
        showAward = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Called by the overlay once it has floated off, so the two never disagree
    /// about how long the animation is.
    private func awardFinished(closesCamera: Bool) {
        showAward = false
        award = nil
        camera.reset()
        camera.rearmScanner()
        // A Fight check-in is a finished errand. Leaving the viewfinder up makes
        // the user work out for themselves that it landed.
        if closesCamera { dismiss() }
    }

    // MARK: - Fight check-in

    /// A Fight QR was recognised. Non-Fight codes never reach here — the camera
    /// drops anything without the `ecohabit://fight/` scheme.
    private func checkIn(withCode code: String) {
        // A reward already playing owns the screen.
        guard !showAward else { return }

        // A QR sitting in frame is re-reported on every metadata callback, many
        // times a second. Without this, one poster that cannot be checked into
        // raises the same toast dozens of times.
        guard code != lastRejectedCode else { return }

        guard let fight = app.fight(matchingCode: code) else {
            reject(code, "That code isn't for any Fight here.")
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // `AwardOverlay` below names the Fight and counts up its points, so the
        // success toast would be the same sentence twice. Refusals still toast.
        let result = app.checkIn(to: fight, code: code, announcesSuccess: false)

        // `AppState.checkIn` raises the toast for the window, the cancelled
        // state and a second scan. The camera stays open for those — none of
        // them mean the user did anything wrong — but the code is parked so
        // it does not fire again while it is still in view.
        guard case .checkedIn(let points) = result else {
            lastRejectedCode = code
            rearmAfterCooldown()
            return
        }

        award = Reward(
            icon: Image(fight.category.icon),
            title: fight.title,
            points: points,
            tint: fight.category.tint,
            badgeName: nil,
            closesCamera: true
        )
        lastRejectedCode = nil
        showAward = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func reject(_ code: String, _ message: String) {
        lastRejectedCode = code
        app.toast = Toast(kind: .warning, message: message)
        rearmAfterCooldown()
    }

    /// Long enough for the toast to be read before the same code could be
    /// reported again, and long enough that pointing away and back re-reports.
    private func rearmAfterCooldown() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            camera.rearmScanner()
            lastRejectedCode = nil
        }
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
            camera.reset()
            showingPicker = true
        case .rejected:
            // Straight back to the viewfinder. No picker: the point of naming what was
            // in frame is that the next photo should be of something else.
            overlay = nil
            camera.reset()
        case .analyzing:
            break   // nothing to skip to — the classifier decides where we go
        }
    }

    private func mascot(_ kind: Overlay) -> String {
        switch kind {
        // The pink "?!" mascot fronts both the intro and the miss, as designed.
        case .firstTimer, .whoops, .rejected: return "mascot-whoops"
        case .analyzing: return "mascot-analyzing"
        }
    }

    private func title(_ kind: Overlay) -> String {
        switch kind {
        case .firstTimer: return "Show us what you did!"
        case .analyzing: return "Wait a Minute…"
        // `.whoops` fronts both outcomes the picker serves. Claiming "we can't identify
        // that" when the model DID have a plausible guess made the camera look blind
        // even when it was working — and made the suggestions below look arbitrary
        // rather than earned.
        case .whoops: return sawSomething ? "Is this it?" : "Whoops!"
        case .rejected: return "That's not it"
        }
    }

    private func message(_ kind: Overlay) -> String {
        switch kind {
        case .firstTimer: return "Take a picture of your action and log it in seconds."
        case .analyzing: return "We're identifying your action.\nThis will only take a moment."
        case .whoops:
            return sawSomething
                ? "We spotted something — pick the right one and we'll log it for you!"
                : "We can't identify that but you can choose what you did and we'll log it for you!"
        // Names what was actually in frame. "We can't identify that" would be untrue —
        // it identified something and refused it — and the difference is what tells
        // somebody to point at a different thing rather than press again.
        case .rejected(let label): return "That looks like \(label). Try again with your action in frame."
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

// MARK: - Award overlay

private struct AwardOverlay: View {
    /// Takes what it draws rather than a domain type, so the same timeline
    /// serves a logged habit and a Fight check-in. Two callers, one
    /// animation — a second copy would drift the moment either was retuned.
    let icon: Image
    let title: String
    let points: Int
    let tint: Color
    /// Named under the points when a Fight hands one over.
    var badgeName: String? = nil
    var onFinished: () -> Void = {}

    /// Honours Settings → Accessibility → Motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var punched = false     // icon slams in
    @State private var burst = false       // ring + sparks
    @State private var showNumber = false
    @State private var counted = 0
    @State private var showName = false
    @State private var floatAway = false   // everything rises and fades

    private static let sparkCount = 10

    var body: some View {
        ZStack {
            legibilityWash

            VStack(spacing: 2) {
                iconBurst
                number
                name
            }
            // The exit: the entire group lifts and dissolves together, the way a
            // collected item leaves rather than being closed.
            .offset(y: floatAway ? -70 : 0)
            .opacity(floatAway ? 0 : 1)
        }
        .allowsHitTesting(false)
        .onAppear(perform: play)
    }

    // MARK: - Pieces

    /// No border, no fill edge — it just makes the middle of the screen a little
    /// deeper so white text survives a bright frame.
    private var legibilityWash: some View {
        RadialGradient(
            colors: [.black.opacity(0.55), .black.opacity(0.28), .clear],
            center: .center, startRadius: 10, endRadius: 260
        )
        .ignoresSafeArea()
        .opacity(floatAway ? 0 : 1)
    }

    /// The icon plus the ring and sparks that leave from behind it.
    private var iconBurst: some View {
        ZStack {
            // Ring leaving from behind the icon reads as impact.
            Circle()
                .stroke(tint, lineWidth: burst ? 1 : 7)
                .frame(width: 104, height: 104)
                .scaleEffect(burst ? 2.1 : 0.55)
                .opacity(burst ? 0 : 0.95)

            sparks

            icon
                .resizable().scaledToFit()
                // Applies to the SF Symbol a Fight passes; the category mascots
                // render with their own colours and ignore it.
                .foregroundStyle(tint)
                .frame(width: 104, height: 104)
                .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                // Overshoot past 1.0 and settle — the punch that makes it feel
                // like it arrived rather than appeared.
                .scaleEffect(punched ? 1 : 0.35)
                .rotationEffect(.degrees(punched ? 0 : -18))
        }
    }

    /// The hero. Games make the number big and everything else small.
    private var number: some View {
        Text("+\(counted)")
            .font(.system(size: 68, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
            .shadow(color: tint.opacity(0.9), radius: 18)
            .scaleEffect(showNumber ? 1 : 0.4)
            .opacity(showNumber ? 1 : 0)
    }

    private var name: some View {
        VStack(spacing: 1) {
            Text("points")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .textCase(.uppercase)
                .tracking(2)

            Text(title)
                .font(Theme.F.body(16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.S.x6)

            if let badgeName {
                Label(badgeName, systemImage: "rosette")
                    .font(Theme.F.body(13, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(.top, 4)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
        .opacity(showName ? 1 : 0)
        .offset(y: showName ? 0 : 10)
    }

    private var sparks: some View {
        ZStack {
            ForEach(0..<Self.sparkCount, id: \.self) { i in
                let angle = Double(i) / Double(Self.sparkCount) * 2 * .pi
                // Alternating sizes so the ring of dots doesn't look mechanical.
                let size: CGFloat = i.isMultiple(of: 2) ? 9 : 6
                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)
                    .shadow(color: tint.opacity(0.8), radius: 6)
                    .offset(x: burst ? cos(angle) * 108 : 0,
                            y: burst ? sin(angle) * 108 : 0)
                    .opacity(burst ? 0 : 1)
                    .scaleEffect(burst ? 0.3 : 1)
            }
        }
    }

    // MARK: - Timeline

    private func play() {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.2)) {
                punched = true; showNumber = true; showName = true
            }
            counted = points
            finish(after: 1.5)
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { punched = true }
        withAnimation(.easeOut(duration: 0.6).delay(0.05)) { burst = true }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55).delay(0.12)) { showNumber = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.18)) { counted = points }
        withAnimation(.easeOut(duration: 0.28).delay(0.26)) { showName = true }

        // Hold long enough to read the action name, then leave.
        withAnimation(.easeIn(duration: 0.55).delay(2)) { floatAway = true }
        finish(after: 1.75)
    }

    private func finish(after seconds: Double) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            onFinished()
        }
    }
}

// MARK: - Previews

/// Tuning the sequence needs to see it many times over. Doing that through a
/// real capture means walking around pointing a phone at a bottle for every
/// 40 ms adjustment, so the overlay gets its own preview with a replay button.
#Preview("Award — replay") {
    struct Harness: View {
        @State private var run = 0
        private let samples = MockData.habits.filter { $0.evidenceStrength == .direct }

        var body: some View {
            ZStack {
                // A busy, bright backdrop rather than flat black — this plays
                // over a live camera feed, and the only real question is whether
                // white numerals survive whatever is behind them.
                LinearGradient(colors: [.orange, .white, .teal, .gray],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                AwardOverlay(
                    icon: Image(samples[run % samples.count].category.mascotName),
                    title: samples[run % samples.count].name,
                    points: [7, 14, 20, 27][run % 4],
                    tint: samples[run % samples.count].category.accentColor,
                    badgeName: run.isMultiple(of: 3) ? "Shoreline Keeper" : nil
                )
                .id(run)   // new identity each tap, so onAppear fires again

                VStack {
                    Spacer()
                    Button("Replay") { run += 1 }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 40)
                }
            }
        }
    }
    return Harness()
}
