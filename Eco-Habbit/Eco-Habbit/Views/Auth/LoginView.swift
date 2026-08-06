import SwiftUI

/// Form-level validation only — there is no auth backend at this stage. A well-formed
/// email plus a 6+ character password gets you in, and the account is stored locally.
struct LoginView: View {
    @EnvironmentObject private var app: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.C.accent2_100, Theme.C.bg],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.65)
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("ECO HABIT")
                        .font(Theme.F.heading(15))
                        .tracking(1)
                        .foregroundStyle(Theme.C.accent700)
                        .padding(.top, 24)

                    GlobeView(health: 82, size: 150, interactive: false)
                        .padding(.top, 34)

                    VStack(spacing: 12) {
                        Text("Small habits.\nA healthier planet.")
                            .font(Theme.F.heading(30))
                            .foregroundStyle(Theme.C.text)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                        Text("Track everyday sustainable actions, watch your impact grow, and help this globe heal.")
                            .font(Theme.F.body(15.5))
                            .foregroundStyle(Theme.C.neutral700)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                    }
                    .padding(.top, 26)

                    VStack(spacing: 14) {
                        EHTextField(
                            label: "Email",
                            placeholder: "you@example.com",
                            text: $email,
                            keyboard: .emailAddress,
                            contentType: .username,
                            error: emailError
                        )

                        EHTextField(
                            label: "Password",
                            placeholder: "At least 6 characters",
                            text: $password,
                            isSecure: true,
                            contentType: .password,
                            error: passwordError
                        )
                    }
                    .padding(.top, 30)

                    Button(action: signIn) {
                        if isSigningIn {
                            ProgressView().tint(Theme.C.bg)
                        } else {
                            Text("Log in")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSigningIn)
                    .padding(.top, 22)

                    Button("Continue with the demo account") {
                        email = MockData.demoEmail
                        password = MockData.demoPassword
                        signIn()
                    }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.top, 4)

                    Text("No account yet? Logging in creates one on this device.")
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(Theme.C.neutral600)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func signIn() {
        emailError = nil
        passwordError = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        if trimmedEmail.isEmpty {
            emailError = "Enter your email"
        }
        if password.count < 6 {
            passwordError = "Use at least 6 characters"
        }
        guard emailError == nil, passwordError == nil else { return }

        isSigningIn = true
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            if !app.logIn(email: trimmedEmail, password: password) {
                emailError = "That doesn't look like a valid email"
            }
            isSigningIn = false
        }
    }
}

#Preview {
    LoginView().environmentObject(AppState(data: PersistedState()))
}
