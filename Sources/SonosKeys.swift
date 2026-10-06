import SwiftUI
import AppKit

@main
struct SonosKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView(model: delegate.model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem!
    private let menu = NSPopover()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "hifispeaker.fill", accessibilityDescription: "Sonos Keys")
        button.target = self
        button.action = #selector(showMenu)
        model.attachStatusButton(button)
        menu.behavior = .transient
        menu.contentViewController = NSHostingController(rootView: MenuView(
            model: model,
            openSettings: { [weak self] in self?.showSettings() },
            openAbout: { [weak self] in self?.showAbout() }
        ))
    }

    @objc private func showMenu() {
        guard let button = statusItem.button else { return }
        if menu.isShown { menu.close() }
        else { menu.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    private func showAbout() {
        menu.close()
        let credits = NSMutableAttributedString(
            string: "Xonay Media",
            attributes: [.link: URL(string: "https://xonaymedia.nl")!, .font: NSFont.systemFont(ofSize: 12)]
        )
        credits.append(NSAttributedString(
            string: "\n\nFor non-commercial use only.",
            attributes: [.font: NSFont.systemFont(ofSize: 12)]
        ))
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Sonos Keys",
            .copyright: "© 2026 Michael Teeuw, Xonay Media",
            .credits: credits
        ])
    }

    private func showSettings() {
        menu.close()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 488, height: 700), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Sonos Keys Settings"
            window.isReleasedWhenClosed = false
            let view = NSHostingView(rootView: SettingsView(model: model, onClose: { [weak window] in window?.close() }))
            window.contentView = view
            window.setContentSize(view.fittingSize)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}
