import LocalAuthentication

/// Thin wrapper over LocalAuthentication. `.deviceOwnerAuthentication` asks
/// for Touch ID or a paired Apple Watch and falls back to the login password,
/// so Latchbar never stores a secret of its own.
@MainActor
enum Authenticator {

    /// Finishes the sentence "Latchbar is trying to …" in the system prompt.
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    /// Label for the unlock button, so it names what will actually happen.
    static var unlockLabel: String {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return "Unlock with Password"
        }
        return context.biometryType == .touchID ? "Unlock with Touch ID" : "Unlock"
    }
}
