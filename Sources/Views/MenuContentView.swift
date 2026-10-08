import SwiftUI

/// The menu bar dropdown. Anything that weakens protection asks for Touch ID
/// first; otherwise the menu itself would be the bypass.
struct MenuContentView: View {
    let engine: LockEngine
    @Bindable var settings: LockSettings

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let count = settings.lockedApps.count
        Text(count == 1 ? "1 app protected" : "\(count) apps protected")

        Divider()

        Button("Lock All Now") { engine.lockAll() }
            .keyboardShortcut("l")
            .disabled(!settings.isEnabled)

        if settings.isEnabled {
            Button("Pause Locking") {
                Task {
                    if await engine.authorizeChange("pause app locking") { settings.isEnabled = false }
                }
            }
        } else {
            Button("Resume Locking") {
                settings.isEnabled = true
                engine.lockAll()
            }
        }

        Divider()

        Button("Settings…") {
            Task {
                guard await engine.authorizeChange("open Latchbar settings") else { return }
                NSApp.activate()
                openSettings()
            }
        }
        .keyboardShortcut(",")

        Button("Quit Latchbar") {
            Task {
                if await engine.authorizeChange("quit Latchbar") { NSApp.terminate(nil) }
            }
        }
        .keyboardShortcut("q")
    }
}
