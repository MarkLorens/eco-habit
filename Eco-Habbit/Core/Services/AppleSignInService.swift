import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation

/// Sign in with Apple, exchanged for a Firebase session.
///
/// Lives here rather than in the sign-in view for the same reason the economy lives in
/// `Core/Services/`: it is a rule, not a layout, and the view should only have to say
/// "this succeeded" or "this failed".
enum AppleSignInService {

    /// What a completed sign-in yields.
    struct Account {
        let uid: String
        /// Populated on the **first ever** sign-in for an Apple ID and `nil` every time
        /// after — permanently, even across reinstalls. Whoever receives this must store
        /// it immediately or it is gone.
        let displayName: String?
    }

    enum Failure: Error, LocalizedError {
        case cancelled
        case noIdentityToken
        case firebase(Error)

        var errorDescription: String? {
            switch self {
            case .cancelled:       return nil
            case .noIdentityToken: return "Apple didn't return a sign-in token. Try again."
            case .firebase(let error):
                // Authentication, unlike Firestore reads, does not work offline at all —
                // and at a booth that is the likeliest failure by far. Say something a
                // visitor can act on rather than an SDK string.
                let code = (error as NSError).code
                if code == AuthErrorCode.networkError.rawValue {
                    return "No connection. Check your network and try again."
                }
                return error.localizedDescription
            }
        }
    }

    // MARK: - Request

    /// The raw nonce for the request currently in flight.
    ///
    /// Apple is sent the SHA-256 **hash**; Firebase is later sent this **raw** string,
    /// and checks that hashing it reproduces what Apple signed. Send the same form to
    /// both and Firebase rejects the credential with an error that never mentions
    /// nonces — which is why this is stored rather than recomputed.
    private static var currentNonce: String?

    /// Configure the authorization request. Call from `SignInWithAppleButton`'s
    /// `onRequest`.
    static func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    // MARK: - Completion

    /// Exchange Apple's credential for a Firebase session.
    static func completeSignIn(with result: Result<ASAuthorization, Error>) async -> Result<Account, Failure> {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return .failure(.cancelled) }
            return .failure(.firebase(error))

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce
            else { return .failure(.noIdentityToken) }

            currentNonce = nil

            // RAW nonce here. Apple got the hash.
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            do {
                let displayName = name(from: credential)
                // Stashed before the sign-in call, because signing in fires the auth
                // listener — and the listener is what starts the session. Only the
                // credential carries the name, and only on the first ever sign-in, so
                // it has to be waiting when the listener arrives.
                pendingDisplayName = displayName

                let result = try await Auth.auth().signIn(with: firebaseCredential)
                return .success(Account(uid: result.user.uid, displayName: displayName))
            } catch {
                pendingDisplayName = nil
                return .failure(.firebase(error))
            }
        }
    }

    /// Name from the sign-in that is currently completing, waiting for the auth
    /// listener to pick it up. Read once — a later session must not reuse it.
    private static var pendingDisplayName: String?

    private static func consumePendingDisplayName() -> String? {
        defer { pendingDisplayName = nil }
        return pendingDisplayName
    }

    static func signOut() {
        pendingDisplayName = nil
        try? Auth.auth().signOut()
    }

    /// Fires immediately with the restored user, so a returning visitor is known before
    /// the first frame and never sees the sign-in screen flash.
    ///
    /// Reports the name as well as the uid. **Firebase keeps the display name it was
    /// given at the first sign-in**, on its own user record, which is the only copy that
    /// survives the app being deleted: Apple hands over `fullName` exactly once per
    /// Apple ID and returns `nil` on every sign-in after that, while the local file that
    /// held it is gone with the app. Without this a reinstalling user is greeted as
    /// "there" forever.
    @discardableResult
    static func observeSession(
        _ onChange: @escaping (_ uid: String?, _ displayName: String?) -> Void
    ) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            // A name from the sign-in happening right now wins — it is the freshest, and
            // on a genuine first sign-in it is the only one that exists yet.
            let name = consumePendingDisplayName()
                ?? user?.displayName?.trimmingCharacters(in: .whitespaces)
            onChange(user?.uid, (name?.isEmpty ?? true) ? nil : name)
        }
    }

    static var currentUserId: String? { Auth.auth().currentUser?.uid }

    // MARK: - Helpers

    private static func name(from credential: ASAuthorizationAppleIDCredential) -> String? {
        guard let components = credential.fullName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let full = formatter.string(from: components).trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? nil : full
    }

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            // Only fails if the system CSPRNG is unavailable, at which point nothing
            // about this sign-in is trustworthy anyway.
            fatalError("SecRandomCopyBytes failed")
        }
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
