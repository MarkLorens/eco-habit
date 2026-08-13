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

    /// Set once a log lands, to drive the reward animation.
    @State private var award: (activity: Activity, points: Int)?
    @State private var showAward = false

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

            if showAward, let award {
                AwardOverlay(activity: award.activity, points: award.points)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.verdict) { _, verdict in
            // A confident, direct match needs no confirmation — log it.
            if case .confident(let match) = verdict,
               let activity = MockActivityData.activity(withID: match.habitId) {
                log(activity)
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
        let activity = MockActivityData.activity(withID: match.habitId)
        let logged = app.isCompletedToday(match.habitId)
        let strength = activity?.evidenceStrength

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

            Text(activity?.name ?? match.habitId)
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
                if let activity = MockActivityData.activity(withID: match.habitId) {
                    candidateRow(activity)
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

    /// An already-logged activity is greyed with a label rather than hidden —
    /// hiding it makes the camera look broken.
    private func candidateRow(_ activity: Activity) -> some View {
        let available = !app.isCompletedToday(activity.id)

        return Button {
            guard available else { return }
            log(activity)
        } label: {
            HStack(spacing: Theme.S.x3) {
                Image(activity.category.mascotName)
                    .resizable().scaledToFit()
                    .frame(width: 26, height: 26)

                Text(activity.name)
                    .font(Theme.F.body(15, weight: .semibold))
                    .foregroundStyle(available ? Theme.C.text : Theme.C.neutral600)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: Theme.S.x2)

                // Same projection the actions list uses — the two screens must
                // never quote different numbers for the same action.
                Text(available ? "+\(app.projectedPoints(for: activity).finalPoints)" : "done")
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

    private func log(_ activity: Activity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            // The one place that sets `hasEvidence`. It no longer multiplies
            // points — that bonus was cut — but it still feeds the photo count
            // behind the "Proof in Pictures" badge.
            let result = await app.logActivity(activity, hasEvidence: true, source: .camera)

            guard case .success(let outcome) = result else {
                camera.reset()
                return
            }
            award = (activity, outcome.breakdown.finalPoints)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { showAward = true }

            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.25)) { showAward = false }
            camera.reset()
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

/// The "here's what you did" moment. Names the action rather than just showing
/// a number, because the number means nothing without it.
private struct AwardOverlay: View {
    let activity: Activity
    let points: Int

    @State private var pop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: Theme.S.x3) {
                Image(activity.category.mascotName)
                    .resizable().scaledToFit()
                    .frame(width: 96, height: 96)
                    .scaleEffect(pop ? 1 : 0.6)

                Text(activity.name)
                    .font(Theme.F.heading(21))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("+\(points) pts")
                    .font(Theme.F.heading(34))
                    .foregroundStyle(Theme.C.accent700)
                    .scaleEffect(pop ? 1 : 0.5)
            }
            .padding(.horizontal, Theme.S.x6)
            .padding(.vertical, Theme.S.x8)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(activity.category.cardBackground)
            )
            .padding(.horizontal, Theme.S.x6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.05)) { pop = true }
        }
    }
}
