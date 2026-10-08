import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: LockSettings

    var body: some View {
        TabView {
            AppsTab(settings: settings)
                .tabItem { Label("Apps", systemImage: "lock.app.dashed") }
            GeneralTab(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 440, height: 360)
    }
}

private struct AppsTab: View {
    @Bindable var settings: LockSettings
    @State private var selection: LockedApp.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $selection) {
                ForEach(settings.lockedApps) { app in
                    HStack(spacing: 10) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text(app.name)
                    }
                    .tag(app.id)
                }
            }
            .overlay {
                if settings.lockedApps.isEmpty {
                    ContentUnavailableView(
                        "No Locked Apps",
                        systemImage: "lock.open",
                        description: Text("Add an app to require Touch ID or your password before it opens.")
                    )
                }
            }

            HStack(spacing: 0) {
                Button { chooseApps() } label: { Image(systemName: "plus").frame(width: 24, height: 20) }
                Button {
                    if let app = settings.lockedApps.first(where: { $0.id == selection }) {
                        settings.remove(app)
                        selection = nil
                    }
                } label: { Image(systemName: "minus").frame(width: 24, height: 20) }
                .disabled(selection == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(6)
        }
        .padding()
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Lock"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let app = LockedApp(bundleURL: url) { settings.add(app) }
        }
    }
}

private struct GeneralTab: View {
    @Bindable var settings: LockSettings

    var body: some View {
        Form {
            Picker("Relock an unlocked app", selection: $settings.gracePeriod) {
                ForEach(LockSettings.GracePeriod.allCases) { Text($0.label).tag($0) }
            }
            Text("Counted from when you switch away from the app.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Relock everything when the Mac sleeps or the screen locks", isOn: $settings.relockOnSleep)

            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            if settings.loginItemRefused {
                Text("Launch at login needs a signed build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
