import Foundation
import Observation
import ServiceManagement

/// User preferences, persisted in `UserDefaults` and observed by the views.
@MainActor
@Observable
final class LockSettings {

    /// How long an unlocked app stays unlocked after you switch away from it.
    enum GracePeriod: Int, CaseIterable, Identifiable, Sendable {
        case immediately = 0
        case oneMinute = 60
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case oneHour = 3600
        case untilQuit = -1

        var id: Int { rawValue }

        /// Nil means the unlock never expires while the app is running.
        var interval: TimeInterval? { self == .untilQuit ? nil : TimeInterval(rawValue) }

        var label: String {
            switch self {
            case .immediately: "Immediately"
            case .oneMinute: "After 1 minute"
            case .fiveMinutes: "After 5 minutes"
            case .fifteenMinutes: "After 15 minutes"
            case .oneHour: "After 1 hour"
            case .untilQuit: "When the app quits"
            }
        }
    }

    private(set) var lockedApps: [LockedApp] {
        didSet {
            if let data = try? JSONEncoder().encode(lockedApps) {
                defaults.set(data, forKey: Key.lockedApps)
            }
        }
    }

    /// Master switch. Off means nothing is locked, but the list is kept.
    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    var gracePeriod: GracePeriod {
        didSet { defaults.set(gracePeriod.rawValue, forKey: Key.gracePeriod) }
    }

    /// Relock everything when the Mac sleeps or the screen locks — the
    /// "walked away from my laptop" case.
    var relockOnSleep: Bool {
        didSet { defaults.set(relockOnSleep, forKey: Key.relockOnSleep) }
    }

    /// True once a registration attempt has actually been refused, which only
    /// happens on unsigned builds.
    private(set) var loginItemRefused = false

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            applyLaunchAtLogin()
        }
    }

    private let defaults: UserDefaults

    private enum Key {
        static let lockedApps = "lockedApps"
        static let isEnabled = "isEnabled"
        static let gracePeriod = "gracePeriod"
        static let relockOnSleep = "relockOnSleep"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.lockedApps = defaults.data(forKey: Key.lockedApps)
            .flatMap { try? JSONDecoder().decode([LockedApp].self, from: $0) } ?? []
        // `bool(forKey:)` is false for a missing key; both switches default on.
        self.isEnabled = defaults.object(forKey: Key.isEnabled) as? Bool ?? true
        self.relockOnSleep = defaults.object(forKey: Key.relockOnSleep) as? Bool ?? true
        // Read as an optional: `integer(forKey:)` would turn a missing key
        // into 0, which is a valid choice (`.immediately`).
        self.gracePeriod = (defaults.object(forKey: Key.gracePeriod) as? Int)
            .flatMap(GracePeriod.init(rawValue:)) ?? .fiveMinutes

        // The login-item state lives in the system, so read it back rather
        // than trusting a cached copy.
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func isLocked(_ bundleID: String) -> Bool {
        lockedApps.contains { $0.bundleID == bundleID }
    }

    func add(_ app: LockedApp) {
        // Locking ourselves would leave no way to reach the settings.
        guard app.bundleID != Bundle.main.bundleIdentifier, !isLocked(app.bundleID) else { return }
        lockedApps.append(app)
        lockedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func remove(_ app: LockedApp) {
        lockedApps.removeAll { $0.bundleID == app.bundleID }
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemRefused = false
        } catch {
            loginItemRefused = true
            // Roll the toggle back so the UI keeps reflecting reality.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
