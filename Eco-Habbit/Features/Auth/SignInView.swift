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
    @EnvironmentObject private var app: AppState
    @State private var errorMessage: String?

    @State private var askingPassword = false
    @State private var password = ""

    var body: some View {
        VStack(spacing: 24) {
            GlobeView()

            Text("Earthie")
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)

            SignInWithAppleButton(.signIn) { request in
                AppleSignInService.prepare(request)
            } onCompletion: { result in
                Task { await handle(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(Capsule())
            .padding(.horizontal, 40)

            // Ships in Release too, not just DEBUG. TestFlight builds *are* Release, so
            // a debug-only escape hatch is invisible to the one person who cannot build
            // the app themselves.
            //
            // Behind a password because it now *does* ship: without one, anybody handed
            // a build walks past sign-in, and the accounts stop meaning anything.
            #if DEBUG
            Button("Continue without an account") {
                password = ""
                askingPassword = true
            }
            .textStyle(Tokens.Typography.body)
            .foregroundStyle(Tokens.Semantic.footnote)
            .padding(.top, -8)
            #endif // debug
            if let errorMessage {
                Text(errorMessage)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Palette.white)
        .alert("Team access", isPresented: $askingPassword) {
            SecureField("Password", text: $password)
            Button("Cancel", role: .cancel) { password = "" }
            Button("Continue") { unlock() }
                .keyboardShortcut(.defaultAction)
        } message: {
            Text("Skipping sign-in is for the team. Nothing you do is saved to an account.")
        }
    }

    private func unlock() {
        // `TeamAccess` owns the password and the trimming. Nothing behind this door
        // can touch another account anyway — a skipped session has no `userId` and
        // writes only to the reserved `local` store.
        let entered = password
        password = ""

        guard TeamAccess.accepts(entered) else {
            errorMessage = "That password isn't right."
            return
        }
        errorMessage = nil
        app.continueWithoutAccount()
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
