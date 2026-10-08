import SwiftUI

@main
struct LatchbarApp: App {

    @State private var settings: LockSettings
    @State private var engine: LockEngine

    init() {
        let settings = LockSettings()
        _settings = State(initialValue: settings)
        let engine = LockEngine(settings: settings)
        _engine = State(initialValue: engine)

        // Locking has to be live from launch, not from the first menu open.
        engine.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(engine: engine, settings: settings)
        } label: {
            Image(systemName: settings.isEnabled ? "lock.fill" : "lock.open")
        }

        Settings {
            SettingsView(settings: settings)
        }
    }
}
