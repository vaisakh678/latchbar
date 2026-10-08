import AppKit
import Observation

/// Watches app activation and hides any locked app until the user
/// authenticates.
///
/// Hiding (rather than covering the app with a window) needs no extra
/// permissions, but the app's window can flash for a frame before it is
/// hidden. It is a deterrent against someone borrowing an unlocked Mac, not
/// a security boundary: anyone at the keyboard can quit Latchbar from
/// Activity Monitor.
@MainActor
@Observable
final class LockEngine {

    let settings: LockSettings

    private var state = LockState()
    private var isAuthenticating = false

    @ObservationIgnored private lazy var prompt = LockPromptController(engine: self)

    init(settings: LockSettings) {
        self.settings = settings
    }

    func start() {
        observeApps(NSWorkspace.didActivateApplicationNotification) { [weak self] in self?.appDidActivate($0) }
        observeApps(NSWorkspace.didDeactivateApplicationNotification) { [weak self] app in
            guard let id = app.bundleIdentifier else { return }
            self?.state.didLeave(id)
        }
        // Apps opened in the background (login items, `open -g`) never
        // activate, so hide them on launch as well.
        observeApps(NSWorkspace.didLaunchApplicationNotification) { [weak self] app in
            guard let self, let id = app.bundleIdentifier, needsUnlock(id) else { return }
            app.hide()
        }
        observeApps(NSWorkspace.didTerminateApplicationNotification) { [weak self] app in
            guard let id = app.bundleIdentifier else { return }
            self?.state.forget(id)
        }

        let relock: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.relockOnSleep else { return }
                self.lockAll()
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: relock)
        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main, using: relock)
        // Posted when the screen locks (Ctrl-Cmd-Q, hot corner, lid close).
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main, using: relock
        )

        // Anything already open when Latchbar starts is locked too.
        lockAll()
    }

    /// Forgets every unlock and hides all running locked apps.
    func lockAll() {
        state.relockAll()
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier, needsUnlock(id) { app.hide() }
        }
    }

    /// Gate for actions that would weaken protection: opening Settings,
    /// pausing, quitting. Free while nothing is locked, so first run is smooth.
    func authorizeChange(_ reason: String) async -> Bool {
        if settings.lockedApps.isEmpty { return true }
        return await Authenticator.authenticate(reason: reason)
    }

    func unlock(_ app: NSRunningApplication) async {
        guard !isAuthenticating, let id = app.bundleIdentifier else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let name = app.localizedName ?? "this app"
        guard await Authenticator.authenticate(reason: "unlock \(name)") else { return }

        state.didUnlock(id)
        prompt.dismiss()
        app.unhide()
        // Since macOS 14 activation is cooperative: we hold focus (the prompt
        // was key), so hand it over explicitly.
        NSApp.yieldActivation(to: app)
        app.activate()
    }

    private func appDidActivate(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier else { return }
        guard needsUnlock(id) else {
            state.didReturn(id)
            return
        }
        app.hide()
        // A second locked app activating mid-prompt just stays hidden; the
        // user can return to it once the current prompt is done.
        guard !isAuthenticating else { return }
        prompt.present(for: app)
    }

    private func needsUnlock(_ id: String) -> Bool {
        guard settings.isEnabled, settings.isLocked(id) else { return false }
        return state.needsUnlock(id, grace: settings.gracePeriod.interval)
    }

    private func observeApps(
        _ name: Notification.Name,
        _ handler: @escaping @MainActor (NSRunningApplication) -> Void
    ) {
        NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { handler(app) }
        }
    }
}
