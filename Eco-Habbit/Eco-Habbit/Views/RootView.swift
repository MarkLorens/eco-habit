import SwiftUI

/// Decides which of the three top-level flows is on screen, and hosts the toast layer.
struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            Theme.C.bg.ignoresSafeArea()

            Group {
                if !app.isLoggedIn {
                    LoginView()
                        .transition(.opacity)
                } else if !app.hasCompletedOnboarding {
                    OnboardingFlow()
                        .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: app.isLoggedIn)
            .animation(.easeInOut(duration: 0.35), value: app.hasCompletedOnboarding)
        }
        .overlay(alignment: .top) {
            ToastLayer()
        }
        .fullScreenCover(isPresented: $app.isCameraPresented) {
            CameraCaptureView()
        }
    }
}

/// Renders `AppState.toast` and clears it after a beat.
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
