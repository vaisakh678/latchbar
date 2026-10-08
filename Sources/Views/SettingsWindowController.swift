import AppKit
import SwiftUI

/// Hosts the settings in a plain window rather than SwiftUI's `Settings`
/// scene. An agent app's `Settings` scene can only be opened from inside a
/// view, and tends to open behind other windows; this one can be shown from
/// anywhere (including first launch) and always comes to the front.
@MainActor
final class SettingsWindowController {

    private let settings: LockSettings
    private var window: NSWindow?

    init(settings: LockSettings) {
        self.settings = settings
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Latchbar Settings"
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
