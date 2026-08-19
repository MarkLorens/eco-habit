import SwiftUI
import AuthenticationServices

/// The screen shown when nobody is signed in.
///
/// Layout is unchanged from the placeholder that stood here before — globe, title,
/// one button. Only the button's behaviour is real now: it used to flip a boolean.
///
/// **This view does not start the session.** It hands the credential to
/// `AppleSignInService` and stops there; the auth listener in `RootView` is the single
/// writer of session state. Calling `signedIn` here as well would give two writers and
/// a race between them.
struct SignInView: View {
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            GlobeView()

            Text("Eco-Habbit")
                .font(Theme.F.heading(28))
                .foregroundStyle(Theme.C.text)

            SignInWithAppleButton(.signIn) { request in
                AppleSignInService.prepare(request)
            } onCompletion: { result in
                Task { await handle(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(Capsule())
            .padding(.horizontal, 40)

            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bg)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) async {
        switch await AppleSignInService.completeSignIn(with: result) {
        case .success:
            // Nothing to do — the listener takes it from here.
            errorMessage = nil
        case .failure(let failure):
            // `cancelled` has no description: backing out is a decision, not an error,
            // and telling somebody off for it would be strange.
            errorMessage = failure.errorDescription
        }
    }
}

#if DEBUG
#Preview {
    SignInView()
}
#endif
