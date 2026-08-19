import SwiftUI

/// Point, shoot, and either it logs itself or it asks.
///
/// The two outcomes come from `EvidenceStrength`. A reusable bottle in frame is
/// `.direct` — the object *is* the proof — so a confident match logs and
/// celebrates. A tap is `.contextual`: the photo shows a tap, it does not show
/// the tap being turned off, so those always ask however sure the model is.
///
/// **No photo is stored.** The frame is classified in memory and discarded.
struct VisualSearchView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()

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
            Color.black.ignoresSafeArea()

            if camera.isAvailable {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                placeholder
            }

            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                detectionReadout
                bottomContent
            }

            // `ToastLayer` also lives in `RootView`, but a `fullScreenCover`
            // presents in its own layer *above* the presenting view's overlays —
            // so every message raised in here was rendering behind the camera and
            // only appearing once it was dismissed. It needs its own copy.
            ToastLayer()

            if showAward, let award {
                AwardOverlay(icon: award.icon,
                             title: award.title,
                             points: award.points,
                             tint: award.tint,
                             badgeName: award.badgeName,
                             onFinished: { awardFinished(closesCamera: award.closesCamera) })
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.scannedFightCode) { _, code in
            guard let code else { return }
            checkIn(withCode: code)
        }
        .onChange(of: camera.verdict) { _, verdict in
            // A confident, direct match needs no confirmation — log it.
            if case .confident(let match) = verdict,
               let habit = MockData.habitsById[match.habitId] {
                log(habit)
            }
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            Spacer()
            Text(hint)
                .font(Theme.F.body(13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.black.opacity(0.35)))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Theme.S.x4)
        .padding(.top, Theme.S.x2)
    }

    private var hint: String {
        if let error = camera.classifierError { return error }
        if camera.permissionDenied { return "Camera access is off" }
        if camera.isAnalysing { return "Looking…" }
        switch camera.verdict {
        case .unsure: return "Which one was it?"
        case .nothing: return "Not sure what that is"
        case .rejected(let d): return "That looks like \(d.label)"
        default: return "Point at what you did"
        }
    }

    // MARK: - Detection readout
    //
    // TEMPORARY — a tuning aid, not product UI. Shows the raw top 3 with their
    // cosines after every shot, including activities already logged today, so
    // "did it detect anything?" has a visible answer. Delete once
    // `minSimilarity` / `autoLogSimilarity` are tuned on a real device.

    @ViewBuilder
    private var detectionReadout: some View {
        if !camera.lastFrame.habits.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("DETECTED")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("p \(camera.lastFrame.confidence, specifier: "%.2f")  ·  log ≥\(camera.autoLogThreshold, specifier: "%.2f")/\(camera.confidenceThreshold, specifier: "%.2f")")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }

                ForEach(camera.lastFrame.habits) { match in
                    readoutRow(match)
                }

                // The line that makes tuning possible: what the frame looked
                // like that ISN'T a habit, and whether it won.
                if let distractor = camera.lastFrame.topDistractor {
                    Divider().overlay(.white.opacity(0.2)).padding(.vertical, 2)
                    let beatsTop = distractor.similarity >= (camera.lastFrame.habits.first?.similarity ?? 0)
                    HStack(spacing: 8) {
                        Text(String(format: "%.3f", distractor.similarity))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(beatsTop ? .red : .white.opacity(0.5))
                        Text(distractor.label)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(beatsTop ? "REJECT" : "not")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(beatsTop ? .red : .white.opacity(0.4))
                    }
                } else {
                    Text("no distractors bundled — rerun ml/generate_vectors.py")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.55)))
            .padding(.horizontal, Theme.S.x4)
            .padding(.bottom, Theme.S.x2)
        }
    }

    private func readoutRow(_ match: HabitMatch) -> some View {
        let habit = MockData.habitsById[match.habitId]
        let logged = app.isCompletedToday(match.habitId)
        let strength = habit?.evidenceStrength

        // Green = would auto-log. Yellow = over the floor but will ask.
        // Grey = below the floor, reported only so you can see the score.
        let colour: Color =
            match.similarity >= camera.autoLogThreshold && strength == .direct ? .green
            : match.similarity >= camera.minThreshold ? .yellow
            : .white.opacity(0.45)

        return HStack(spacing: 8) {
            Text(String(format: "%.3f", match.similarity))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(colour)

            Text(habit?.name ?? match.habitId)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(logged ? 0.45 : 0.9))
                .lineLimit(1)

            Spacer(minLength: 4)

            if logged {
                Text("logged")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Text(strength.map { String($0.rawValue.prefix(4)) } ?? "?")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Bottom

    @ViewBuilder
    private var bottomContent: some View {
        switch camera.verdict {
        case .unsure(let matches):
            candidates(matches)
        case .nothing:
            retry
        case .rejected(let distractor):
            rejected(distractor)
        default:
            shutter
        }
    }

    /// Naming what it saw is the point. "Nothing recognised" invites the user to
    /// try the same shot again; "that's a single-use bottle" tells them the
    /// answer is no and why, which is the whole reason distractors exist.
    private func rejected(_ distractor: DistractorMatch) -> some View {
        VStack(spacing: Theme.S.x3) {
            Text("That looks like \(distractor.label) — not one of your actions.")
                .font(Theme.F.body(14))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.S.x6)

            HStack(spacing: Theme.S.x2) {
                retakeButton
                browseButton
            }
        }
        .padding(.bottom, Theme.S.x6)
    }

    private var shutter: some View {
        VStack(spacing: Theme.S.x3) {
            Button { camera.capture() } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 76, height: 76)
                    Circle().fill(.white).frame(width: 62, height: 62)
                    if camera.isAnalysing {
                        ProgressView().tint(.black)
                    }
                }
            }
            .buttonStyle(PlainPressStyle())
            .disabled(!camera.isReady || camera.isAnalysing)
            .opacity(camera.isReady ? 1 : 0.4)
            .accessibilityLabel("Take a picture to log an action")

            browseButton
        }
        .padding(.bottom, Theme.S.x6)
    }

    private func candidates(_ matches: [HabitMatch]) -> some View {
        VStack(spacing: Theme.S.x2) {
            Text("Tap the one you did")
                .font(Theme.F.body(13))
                .foregroundStyle(.white.opacity(0.8))

            ForEach(matches) { match in
                if let habit = MockData.habitsById[match.habitId] {
                    candidateRow(habit)
                }
            }

            HStack(spacing: Theme.S.x2) {
                retakeButton
                browseButton
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, Theme.S.x4)
        .padding(.bottom, Theme.S.x6)
    }

    /// An already-logged habit is greyed with a label rather than hidden —
    /// hiding it makes the camera look broken.
    private func candidateRow(_ habit: Habit) -> some View {
        let available = !app.isCompletedToday(habit.id)

        return Button {
            guard available else { return }
            log(habit)
        } label: {
            HStack(spacing: Theme.S.x3) {
                Image(habit.category.mascotName)
                    .resizable().scaledToFit()
                    .frame(width: 26, height: 26)

                Text(habit.name)
                    .font(Theme.F.body(15, weight: .semibold))
                    .foregroundStyle(available ? Theme.C.text : Theme.C.neutral600)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: Theme.S.x2)

                // Same projection the actions list uses — the two screens must
                // never quote different numbers for the same action.
                Text(available ? "+\(app.projectedPoints(for: habit).finalPoints)" : "done")
                    .font(Theme.F.body(13, weight: .bold))
                    .foregroundStyle(available ? Theme.C.accent700 : Theme.C.neutral500)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.R.lg)
                    .fill(available ? Theme.C.bg : Theme.C.neutral200)
            )
        }
        .buttonStyle(PlainPressStyle())
        .disabled(!available)
    }

    private var retry: some View {
        VStack(spacing: Theme.S.x3) {
            Text("Nothing recognised. Try getting closer, or pick it by hand.")
                .font(Theme.F.body(14))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.S.x6)

            HStack(spacing: Theme.S.x2) {
                retakeButton
                browseButton
            }
        }
        .padding(.bottom, Theme.S.x6)
    }

    private var retakeButton: some View {
        Button { camera.reset() } label: {
            Text("Retake")
                .font(Theme.F.body(14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.18)))
        }
    }

    private var browseButton: some View {
        Button {
            app.selectedTab = .actions
            dismiss()
        } label: {
            Text("Browse all")
                .font(Theme.F.body(14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.18)))
                .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
        }
    }

    // MARK: - Logging

    private func log(_ habit: Habit) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // main's logging is synchronous — one atomic `mutate` on PersistedState
        // rather than a chain of async repository calls — so this needs no Task.
        // `.visualSearch` is what marks the log as photo-evidence; it is what the
        // evidence badges count.
        let result = app.logAndToast(habit, source: .visualSearch)

        do {
            // `atDailyCap` gets the same treatment as a refusal *for the overlay only* —
            // the log itself has already landed and still counts. `AwardOverlay` counts
            // up to `points`, so at the cap it would run the whole celebration to
            // arrive at "+0". `logAndToast` has already said what happened; go straight
            // back to scanning.
            guard case .logged(let points, let atDailyCap) = result, !atDailyCap else {
                camera.reset()
                return
            }
            award = Reward(
                icon: Image(habit.category.mascotName),
                title: habit.name,
                points: points,
                tint: habit.category.accentColor,
                // main awards badges inside `logAndToast`; the freshest one is
                // whatever landed last in the award log.
                badgeName: app.data.earnedBadges.last?.name,
                closesCamera: false
            )
            // No transition animation here. The overlay runs its own timeline
            // and takes itself away; wrapping it in one would fight that.
            showAward = true
            // The medium impact above acknowledged the shutter. This one is the
            // reward, and it lands with the icon.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
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
        // raises the same toast dozens of times — which is what made the message
        // look "late": it was a backlog draining after the camera closed.
        guard code != lastRejectedCode else { return }

        guard let fight = app.fight(matchingCode: code) else {
            reject(code, "That code isn't for any Fight here.")
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Synchronous on main, and main's result carries only the points — the
        // reward badge an organiser can attach lands with `Fight.rewardBadgeId`
        // when host mode grows a picker for it.
        let result = app.checkIn(to: fight, code: code)

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
            icon: Image(systemName: fight.type.symbol),
            title: fight.title,
            points: points,
            tint: fight.type.tint,
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

    // MARK: - Simulator

    private var placeholder: some View {
        VStack(spacing: Theme.S.x3) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.white.opacity(0.5))
            Text(camera.permissionDenied
                 ? "Camera access is off.\nTurn it on in iOS Settings."
                 : "No camera on this device.")
                .font(Theme.F.body(14))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

/// The pickup moment — deliberately **not** a card.
///
/// A game never puts a reward in a dialog. It happens on top of the world, it
/// moves, and it takes itself away: the icon punches in over the live camera
/// feed, the number is the hero, and the whole group drifts upward and
/// dissolves. Nothing to dismiss and nothing boxed.
///
/// The one concession to a background is `legibilityWash` — a soft radial
/// darkening under the middle of the burst. Without it white numerals vanish
/// against a bright wall, which is the same reason games put a shadow or a
/// gradient under floating combat text. It has no edge, so it never reads as a
/// container.
///
/// Owns its whole lifecycle and calls `onFinished` when it has faded, so the
/// timing lives here rather than in a `Task.sleep` on the far side of the app
/// that has to be kept in step by hand.
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
        withAnimation(.easeIn(duration: 0.55).delay(1.15)) { floatAway = true }
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

// No reduce-motion preview: `accessibilityReduceMotion` is read-only in the
// environment, so it cannot be forced from here. Check that path in the
// simulator under Settings → Accessibility → Motion → Reduce Motion.
