import SwiftUI

@main
struct LatchbarApp: App {

    @State private var settings: LockSettings
    @State private var engine: LockEngine
    private let settingsWindow: SettingsWindowController

    init() {
        let settings = LockSettings()
        _settings = State(initialValue: settings)
        let engine = LockEngine(settings: settings)
        _engine = State(initialValue: engine)
        let settingsWindow = SettingsWindowController(settings: settings)
        self.settingsWindow = settingsWindow

        // Locking has to be live from launch, not from the first menu open.
        engine.start()

        // A menu bar icon alone is easy to miss; with nothing to lock yet,
        // go straight to the place where apps are added.
        if settings.lockedApps.isEmpty {
            Task { settingsWindow.show() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(engine: engine, settings: settings, settingsWindow: settingsWindow)
        } label: {
            Image(systemName: settings.isEnabled ? "lock.fill" : "lock.open")
        }
    }
}
