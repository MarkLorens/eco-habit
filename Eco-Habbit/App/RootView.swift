import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            Theme.C.bg.ignoresSafeArea()

            Group {
                if app.isLoggedIn {
                    MainTabView()
                        .transition(.opacity)
                } else {
                    SignInPlaceholder()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: app.isLoggedIn)
        }
        .overlay(alignment: .top) {
            ToastLayer()
        }
        .modalCard(item: Binding(
            get: { app.pendingBadge },
            set: { if $0 == nil, let badge = app.pendingBadge { app.acknowledgeBadge(badge) } }
        )) { badge in
            BadgeDetailSheet(badge: badge, unlocked: true) { app.acknowledgeBadge(badge) }
        }
        // Above the badge card on purpose: the globe reaching a new stage is the bigger
        // moment, and the badge is still waiting underneath once this is dismissed.
        .globeStageUpOverlay(item: Binding(
            get: { app.pendingGlobeStageUp },
            set: { if $0 == nil, let stageUp = app.pendingGlobeStageUp { app.acknowledgeGlobeStageUp(stageUp) } }
        ))
    }
}

private struct SignInPlaceholder: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 24) {
            GlobeView()
            Text("Eco-Habbit")
                .font(Theme.F.heading(28))
                .foregroundStyle(Theme.C.text)
            Button("Sign In with Apple") {
                app.logIn()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bg)
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
