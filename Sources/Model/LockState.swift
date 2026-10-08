import Foundation

/// Which locked apps are currently unlocked, and for how long.
///
/// Kept free of AppKit so the rules can be unit-tested: an app needs
/// unlocking unless it was unlocked since the last relock *and* it has not
/// been away longer than the grace period.
struct LockState: Sendable {

    /// Bundle IDs unlocked since the last relock.
    private(set) var unlocked: Set<String> = []
    /// When each unlocked app last lost focus; the grace period counts from here.
    private var leftAt: [String: Date] = [:]

    /// - Parameter grace: nil means an unlock lasts until the app quits.
    /// An expired unlock needs no clearing: its `leftAt` stays in the past,
    /// so it keeps reading as locked until the next `didUnlock`.
    func needsUnlock(_ id: String, grace: TimeInterval?, now: Date = .now) -> Bool {
        guard unlocked.contains(id) else { return true }
        guard let grace, let left = leftAt[id] else { return false }
        return now.timeIntervalSince(left) > grace
    }

    mutating func didUnlock(_ id: String) {
        unlocked.insert(id)
        leftAt[id] = nil
    }

    /// Only unlocked apps start a grace timer; a still-locked app leaving
    /// focus (because we just hid it) means nothing.
    mutating func didLeave(_ id: String, at date: Date = .now) {
        guard unlocked.contains(id) else { return }
        leftAt[id] = date
    }

    mutating func didReturn(_ id: String) {
        leftAt[id] = nil
    }

    mutating func forget(_ id: String) {
        unlocked.remove(id)
        leftAt[id] = nil
    }

    mutating func relockAll() {
        unlocked.removeAll()
        leftAt.removeAll()
    }
}
