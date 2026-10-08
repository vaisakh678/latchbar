import AppKit

/// An app the user has chosen to protect. Identified by bundle ID so the lock
/// survives the app being updated or moved; the path is only for the icon.
struct LockedApp: Codable, Hashable, Identifiable, Sendable {
    let bundleID: String
    let name: String
    let path: String

    var id: String { bundleID }

    @MainActor
    var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }

    /// Reads an `.app` bundle picked in the open panel. Nil for anything
    /// without a bundle ID, which there is no way to match at activation.
    init?(bundleURL url: URL) {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
        self.bundleID = bundleID
        self.name = FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
        self.path = url.path
    }
}
