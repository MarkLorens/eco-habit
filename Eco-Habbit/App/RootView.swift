import SwiftUI

/// Decides which of the three top-level states the app is in — resolving, signed in,
/// or signed out — and owns the auth listener that moves between them.
struct RootView: View {
    @EnvironmentObject private var app: AppState

    /// False until the auth listener has reported once. See the `Color.clear` branch.
    @State private var sessionResolved = false

    /// The `-EHDemo` launch path builds a signed-in demo account with no Firebase
    /// session behind it. Letting the listener run would immediately sign it out.
    private var isDemoLaunch: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "EHDemo")
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            Tokens.Palette.white.ignoresSafeArea()

            Group {
                if !sessionResolved {
                    // Nothing, briefly. Firebase is configured in the app delegate,
                    // which runs *after* App.init, so the restored session is not known
                    // until the listener below fires. Rendering the sign-in screen in
                    // the meantime would flash it at every returning user.
                    Color.clear
                } else if !app.isLoggedIn && !app.isBrowsingLocally {
                    SignInView()
                        .transition(.opacity)
                } else if !app.onboardingResolved {
                    // Same reasoning one level down: signed in, but this device may not
                    // know yet that the account has already answered. Deciding now would
                    // re-ask a returning user on a new phone.
                    Color.clear
                } else if !app.hasCompletedOnboarding {
                    OnboardingFlow { answers in
                        app.completeOnboarding(answers)
                    }
                    .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: app.isLoggedIn)
            .animation(.easeInOut(duration: 0.35), value: app.isBrowsingLocally)
            .animation(.easeInOut(duration: 0.35), value: app.hasCompletedOnboarding)
        }
        .task {
            guard !isDemoLaunch else { sessionResolved = true; return }
            // The single writer of session state. The sign-in button deliberately does
            // not call `signedIn` itself — two writers race.
            AppleSignInService.observeSession { uid, displayName in
                if let uid {
                    app.signedIn(uid: uid, displayName: displayName)
                } else {
                    app.signedOut()
                }
                sessionResolved = true
            }
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
