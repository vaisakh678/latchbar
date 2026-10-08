import SwiftUI

/// The menu bar dropdown. Anything that weakens protection asks for Touch ID
/// first; otherwise the menu itself would be the bypass.
struct MenuContentView: View {
    let engine: LockEngine
    @Bindable var settings: LockSettings
    let settingsWindow: SettingsWindowController

    var body: some View {
        let count = settings.lockedApps.count
        if !settings.isEnabled {
            Text("Locking paused")
        } else if count == 0 {
            Text("No apps locked yet")
        } else {
            Text(count == 1 ? "1 app locked" : "\(count) apps locked")
        }

        Divider()

        Button("Lock All Now") { engine.lockAll() }
            .keyboardShortcut("l")
            .disabled(!settings.isEnabled || count == 0)

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
                if await engine.authorizeChange("open Latchbar settings") { settingsWindow.show() }
            }
        }
        .keyboardShortcut(",")

        Button("About Latchbar") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        }

        Button("Quit Latchbar") {
            Task {
                if await engine.authorizeChange("quit Latchbar") { NSApp.terminate(nil) }
            }
        }
        .keyboardShortcut("q")
    }
}
