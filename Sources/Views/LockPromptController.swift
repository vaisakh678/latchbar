import AppKit
import SwiftUI

/// Owns the small floating window shown when a locked app is opened. The
/// system authentication sheet appears on its own; this window is what stays
/// behind if the user cancels it, so they can retry or give up.
@MainActor
final class LockPromptController {

    private unowned let engine: LockEngine
    private var panel: NSPanel?

    init(engine: LockEngine) {
        self.engine = engine
    }

    func present(for app: NSRunningApplication) {
        let view = LockPromptView(
            appName: app.localizedName ?? "This app",
            icon: app.icon ?? NSImage(named: NSImage.applicationIconName)!,
            unlockLabel: Authenticator.unlockLabel,
            onUnlock: { [engine] in Task { await engine.unlock(app) } },
            onCancel: { [weak self] in self?.dismiss() }
        )

        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        // Go straight to Touch ID; the button is for retrying after a cancel.
        Task { await engine.unlock(app) }
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 260),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}

private struct LockPromptView: View {
    let appName: String
    let icon: NSImage
    let unlockLabel: String
    let onUnlock: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 72, height: 72)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.tint, in: Circle())
                        .offset(x: 6, y: 6)
                }

            VStack(spacing: 4) {
                Text("\(appName) is locked")
                    .font(.headline)
                Text("Authenticate to open it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Button(action: onUnlock) {
                    Text(unlockLabel).frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderless)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}
