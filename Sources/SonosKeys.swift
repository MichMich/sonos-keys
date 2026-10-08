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

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let model = AppModel()
    private var statusItem: NSStatusItem!
    private let menu = NSPopover()
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var afterMenuClose: (() -> Void)?
    private var closingMenu = false
    private var allowMenuClose = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "hifispeaker.fill", accessibilityDescription: "Sonos Keys")
        button.target = self
        button.action = #selector(showMenu)
        model.attachStatusButton(button)
        menu.behavior = .transient
        menu.animates = false
        menu.delegate = self
        model.closeMenu = { [weak self] present in
            guard let self = self else { return }
            if self.menu.isShown || self.model.menuVisible {
                self.afterMenuClose = present
                self.closeMenu()
            } else { present() }
        }
        menu.contentViewController = NSHostingController(rootView: MenuView(
            model: model,
            openSettings: { [weak self] in self?.showSettings() },
            openAbout: { [weak self] in self?.showAbout() }
        ))
    }

    func popoverWillShow(_ notification: Notification) { model.setMenuVisible(true) }
    func popoverDidShow(_ notification: Notification) {
        guard let window = menu.contentViewController?.view.window else { return }
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.makeKeyAndOrderFront(nil)
    }
    func popoverDidClose(_ notification: Notification) {
        closingMenu = false
        model.setMenuVisible(false)
        let present = afterMenuClose
        afterMenuClose = nil
        present?()
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if allowMenuClose { return true }
        closeMenu()
        return false
    }

    private func closeMenu() {
        guard !closingMenu, menu.isShown, let window = menu.contentViewController?.view.window else { return }
        closingMenu = true
        let frame = window.frame
        PanelAnimation.close(window) { [weak self, weak window] in
            self?.allowMenuClose = true
            self?.menu.close()
            self?.allowMenuClose = false
            window?.setFrame(frame, display: false)
            window?.alphaValue = 1
        }
    }

    @objc private func showMenu() {
        guard let button = statusItem.button else { return }
        if menu.isShown { closeMenu() }
        else {
            model.prepareMenu { [weak self, weak button] in
                guard let self = self, let button = button else { return }
                NSApp.activate(ignoringOtherApps: true)
                self.menu.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    private func showAbout() {
        closeMenu()
        if aboutWindow == nil {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "About Sonos Keys"
            window.isReleasedWhenClosed = false
            let view = NSHostingView(rootView: AboutView())
            window.contentView = view
            window.setContentSize(view.fittingSize)
            window.center()
            aboutWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow?.makeKeyAndOrderFront(nil)
    }

    private func showSettings() {
        closeMenu()
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
