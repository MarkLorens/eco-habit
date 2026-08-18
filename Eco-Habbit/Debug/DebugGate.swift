import SwiftUI

// DEBUG-only, like everything it guards. A Release build has no debug menu to
// reach, so it has no gate either — and no password sitting in the binary.
#if DEBUG

/// Password prompt in front of the debug tools.
///
/// The tools behind it fake time and grant host verification. Neither is a user
/// feature, and a teammate running this build who taps into them by accident can
/// silently corrupt the state they were about to demo — a streak set to 30, an
/// account promoted to an organisation.
///
/// **This is a speed bump, not security.** The password is in the source and
/// therefore in the binary. It is `#if DEBUG` that does the actual protecting;
/// this only stops an accident.
struct DebugGate: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var entered = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    private static let password = "mangrove"

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.S.x4) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.C.neutral500)
                    .padding(.top, Theme.S.x6)

                Text("Debug tools")
                    .font(Theme.F.heading(21))
                    .foregroundStyle(Theme.C.text)

                Text("Time travel, streak and host verification. Not a user feature.")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("Password", text: $entered)
                    .textFieldStyle(.plain)
                    .font(Theme.F.body(17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit(attempt)
                    .padding(.vertical, Theme.S.x3)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.R.md)
                            .fill(Theme.C.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.R.md)
                                    .stroke(wrong ? Theme.C.accent600 : .clear, lineWidth: 1.5)
                            )
                    )
                    // A shake says "wrong" without a dialog to dismiss.
                    .offset(x: wrong ? 8 : 0)
                    .animation(.default.repeatCount(3, autoreverses: true).speed(6), value: wrong)

                Button("Unlock", action: attempt)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(entered.isEmpty)

                Spacer()
            }
            .padding(.horizontal, Theme.S.x6)
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func attempt() {
        let candidate = entered.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard candidate == Self.password else {
            wrong = true
            entered = ""
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            // Re-arm so a second wrong attempt shakes again.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                wrong = false
            }
            return
        }
        // The caller opens the tools from this sheet's `onDismiss`; presenting
        // a second sheet from inside this one races the dismissal animation and
        // SwiftUI silently drops it.
        app.isDebugUnlocked = true
        dismiss()
    }
}
#endif
