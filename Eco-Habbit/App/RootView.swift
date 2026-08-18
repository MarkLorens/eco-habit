import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            Theme.C.bg.ignoresSafeArea()

            // No sign-in gate: this data model has no auth yet — `userId` is
            // fixed at "demo-user" until Firebase Auth lands (FIREBASE_SETUP §4b).
            // The sign-in screen returns with it.
            MainTabView()
        }
        .overlay(alignment: .top) {
            ToastLayer()
        }
        // Earning a badge is worth interrupting whatever screen you are on, so
        // this sits at the root rather than in Profile. Presented from
        // `pendingBadge`, which is persisted — dismissing is what marks it seen.
        .modalCard(item: Binding(
            get: { app.pendingBadge },
            set: { newValue in
                guard newValue == nil, let badge = app.pendingBadge else { return }
                Task { await app.acknowledgeBadge(badge) }
            }
        )) { badge in
            BadgeDetailSheet(badge: badge, unlocked: true) {
                Task { await app.acknowledgeBadge(badge) }
            }
        }
        .task { await app.bootstrap() }
    }
}

struct ToastLayer: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            if let toast = app.toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.kind.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(toast.message)
                        .font(Theme.F.body(13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Capsule().fill(toast.kind.tint))
                .elevation(Theme.E.md)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(2.6))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.25)) { app.toast = nil }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: app.toast)
    }
}
