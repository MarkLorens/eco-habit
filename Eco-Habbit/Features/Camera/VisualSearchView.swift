import SwiftUI

/// PRD §6.4 — the camera as a search box over the habit catalogue.
///
/// No shutter, because there is nothing to capture. No auto-log, at any
/// confidence: the camera narrows fifty habits down to two or three, and the
/// user decides. Matching habits surface as chips along the bottom edge and
/// update as the camera moves.
struct VisualSearchView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAvailable {
                CameraPreview(session: camera.session).ignoresSafeArea()
            } else {
                placeholder
            }

            // Keeps the chips legible over a bright scene.
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                chipRow
            }
        }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: - Top bar

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
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.black.opacity(0.35)))

            Spacer()

            // Balances the close button so the hint stays centred.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, Theme.S.x4)
        .padding(.top, Theme.S.x2)
    }

    private var hint: String {
        if let error = camera.classifierError { return error }
        if camera.permissionDenied { return "Camera access is off" }
        if !camera.isReady { return "Warming up…" }
        return camera.matches.isEmpty ? "Point at something" : "Tap to log"
    }

    // MARK: - Chips

    private var chipRow: some View {
        VStack(spacing: Theme.S.x2) {
            if camera.matches.isEmpty {
                Text("Point at something, or browse all habits.")
                    .font(Theme.F.body(14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.S.x2) {
                        ForEach(camera.matches) { match in
                            if let habit = MockData.habitsById[match.habitId] {
                                chip(habit)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.S.x4)
                }
            }

            // PRD §6.4 — a persistent way out, beside the chips.
            Button {
                app.selectedTab = .actions
                dismiss()
            } label: {
                Text("Browse all habits")
                    .font(Theme.F.body(14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
            }
        }
        .padding(.bottom, Theme.S.x6)
        .animation(.easeOut(duration: 0.2), value: camera.matches)
    }

    /// PRD §5.4 — an unavailable habit is greyed with a label rather than
    /// hidden. Hiding it makes the camera look broken.
    private func chip(_ habit: Habit) -> some View {
        let available = app.isAvailable(habit)

        return Button {
            guard available else { return }
            app.logAndToast(habit, source: .visualSearch)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(habit.name)
                    .font(Theme.F.body(14, weight: .bold))
                    .foregroundStyle(available ? Theme.C.text : Theme.C.neutral600)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(label(for: habit, available: available))
                    .font(Theme.F.body(11.5, weight: .semibold))
                    .foregroundStyle(available ? Theme.C.accent700 : Theme.C.neutral500)
            }
            .frame(maxWidth: 190, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.R.lg)
                    .fill(available ? Theme.C.bg : Theme.C.neutral200)
            )
        }
        .buttonStyle(PlainPressStyle())
        .disabled(!available)
    }

    private func label(for habit: Habit, available: Bool) -> String {
        // Foundations are gone with the old catalogue — every action in the
        // friction catalogue scores, so there is one label on each side now.
        guard available else { return "Done today" }
        return "+\(habit.basePoints) pts"
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
