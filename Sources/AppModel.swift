import AppKit
import Combine
import ServiceManagement
import CoreAudio

final class AppModel: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var room: String
    @Published private(set) var speakerIP: String
    @Published private(set) var inverted: Bool
    @Published private(set) var volumeStep: Int
    @Published private(set) var error: String?
    @Published private(set) var modifiers: NSEvent.ModifierFlags
    @Published private(set) var rooms: [String] = []
    @Published private(set) var discovering = false
    @Published private(set) var discoveryError: String?
    @Published private(set) var permissionPage: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginApprovalRequired = false
    @Published private(set) var loginError: String?
    @Published private(set) var showTrackInfoInHUD: Bool { didSet { hud.trackInfo.enabled = showTrackInfoInHUD } }
    @Published private(set) var showTrackInfoInMenu: Bool
    var showTrackInfo: Bool { showTrackInfoInHUD || showTrackInfoInMenu }
    @Published private(set) var hudVisible = false
    @Published private(set) var menuVisible = false
    @Published private(set) var track: SonosTrack? { didSet { hud.trackInfo.track = track } }
    @Published private(set) var trackLoading = false
    @Published private(set) var trackError: String?
    @Published private(set) var audioOutputName = "Mac"
    var closeMenu: (() -> Void)?

    var modifierTitle: String {
        MediaKeys.modifiers.filter { modifiers.contains($0.flag) }.map { $0.symbol }.joined(separator: " + ")
    }

    private let defaults = UserDefaults.standard
    private let hud = SonosHUD()
    private var listener: MediaKeys?
    private var pendingCommands = 0
    private var trackTimer: Timer?
    private var trackClient: Sonos?
    private let trackWorker = DispatchQueue(label: "sonos-keys.track-info")

    init() {
        room = defaults.string(forKey: "room") ?? ""
        speakerIP = defaults.string(forKey: "speakerIP") ?? ""
        volumeStep = min(20, max(1, defaults.object(forKey: "volumeStep") as? Int ?? 2))
        modifiers = NSEvent.ModifierFlags(rawValue: UInt(defaults.object(forKey: "modifiers") as? Int ?? Int(NSEvent.ModifierFlags.command.rawValue)))
        inverted = defaults.bool(forKey: "inverted")
        showTrackInfoInHUD = defaults.object(forKey: "showTrackInfoInHUD") as? Bool ?? false
        showTrackInfoInMenu = defaults.object(forKey: "showTrackInfoInMenu") as? Bool ?? false
        hud.trackInfo.enabled = showTrackInfoInHUD
        hud.onVisibilityChange = { [weak self] visible in self?.setHUDVisible(visible) }
        refreshLoginStatus()
        updateTrackPolling()
        if !room.isEmpty && defaults.object(forKey: "enabled") as? Bool != false {
            DispatchQueue.main.async { [weak self] in self?.enable() }
        }
    }

    func save(room: String, speakerIP: String, volumeStep: Int, modifiers: NSEvent.ModifierFlags, inverted: Bool) {
        guard self.room != room.trimmingCharacters(in: .whitespacesAndNewlines)
            || self.speakerIP != speakerIP.trimmingCharacters(in: .whitespacesAndNewlines)
            || self.volumeStep != volumeStep || self.modifiers != modifiers || self.inverted != inverted else { return }
        self.inverted = inverted
        defaults.set(inverted, forKey: "inverted")
        self.modifiers = modifiers
        defaults.set(Int(modifiers.rawValue), forKey: "modifiers")
        self.room = room.trimmingCharacters(in: .whitespacesAndNewlines)
        self.speakerIP = speakerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        self.volumeStep = volumeStep
        defaults.set(self.room, forKey: "room")
        defaults.set(self.speakerIP, forKey: "speakerIP")
        defaults.set(volumeStep, forKey: "volumeStep")
        trackClient = nil
        track = nil
        trackLoading = false
        updateTrackPolling()
        stop()
        enable()
    }

    func setShowTrackInfo(inHUD: Bool, inMenu: Bool) {
        showTrackInfoInHUD = inHUD
        showTrackInfoInMenu = inMenu
        defaults.set(inHUD, forKey: "showTrackInfoInHUD")
        defaults.set(inMenu, forKey: "showTrackInfoInMenu")
        if !showTrackInfo { track = nil }
        updateTrackPolling()
    }

    func setHUDVisible(_ visible: Bool) {
        guard hudVisible != visible else { return }
        if visible { closeMenu?() }
        hudVisible = visible
        updateTrackPolling(refresh: visible && showTrackInfoInHUD)
    }

    func setMenuVisible(_ visible: Bool) {
        menuVisible = visible
        if visible {
            hud.hide()
            refreshAudioOutputName()
        }
        updateTrackPolling(refresh: visible && showTrackInfoInMenu)
    }

    private func refreshAudioOutputName() {
        audioOutputName = "Mac"
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return }
        address.mSelector = kAudioObjectPropertyName
        var name: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &name) == noErr else { return }
        if !(name as String).isEmpty { audioOutputName = name as String }
    }

    private func updateTrackPolling(refresh: Bool = true) {
        trackTimer?.invalidate()
        trackTimer = nil
        guard showTrackInfo && !room.isEmpty else { return }
        if refresh { refreshTrack() }
        let timer = Timer(timeInterval: (hudVisible && showTrackInfoInHUD) || (menuVisible && showTrackInfoInMenu) ? 5 : 15, repeats: true) { [weak self] _ in self?.refreshTrack() }
        RunLoop.main.add(timer, forMode: .common)
        trackTimer = timer
    }

    private func refreshTrack() {
        guard !trackLoading else { return }
        if trackClient == nil {
            trackClient = Sonos(SonosSettings(room: room, volumeStep: volumeStep, speakerIP: speakerIP))
        }
        guard let client = trackClient else { return }
        trackLoading = true
        trackWorker.async { [weak self] in
            let result = Result { try client.currentTrack() }
            DispatchQueue.main.async {
                guard let self = self, self.trackClient === client else { return }
                self.trackLoading = false
                guard self.showTrackInfo else { return }
                switch result {
                case .success(let track):
                    self.track = track
                    self.trackError = nil
                case .failure:
                    self.track = nil
                    self.trackError = "Track info unavailable"
                    self.trackClient = nil
                }
            }
        }
    }

    func discoverRooms(speakerIP: String) {
        guard !discovering else { return }
        discovering = true
        discoveryError = nil
        let sonos = Sonos(SonosSettings(room: room, volumeStep: volumeStep, speakerIP: speakerIP.trimmingCharacters(in: .whitespacesAndNewlines)))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let rooms = try sonos.roomNames()
                DispatchQueue.main.async {
                    self?.rooms = rooms
                    self?.discovering = false
                }
            } catch {
                let message = error.localizedDescription
                DispatchQueue.main.async {
                    self?.discoveryError = message
                    self?.discovering = false
                }
            }
        }
    }

    func toggle() {
        if enabled {
            stop()
            defaults.set(false, forKey: "enabled")
        } else { enable() }
    }

    private func enable() {
        guard !room.isEmpty else { return }
        error = nil
        permissionPage = nil
        let room = room
        let keys = MediaKeys(Sonos(SonosSettings(room: room, volumeStep: volumeStep, speakerIP: speakerIP)), modifiers: modifiers, inverted: inverted)
        keys.onDiscoveryError = { [weak self, weak keys] message in
            guard let self = self, let keys = keys, self.listener === keys else { return }
            self.error = message
        }
        keys.onPending = { [weak self, weak keys] volume in
            guard let self = self, let keys = keys, self.listener === keys else { return }
            self.pendingCommands += 1
            self.hud.show(room: room, feedback: .loading(volume: volume))
        }
        keys.onFeedback = { [weak self, weak keys] feedback in
            guard let self = self, let keys = keys, self.listener === keys else { return }
            self.pendingCommands -= 1
            self.error = nil
            if self.showTrackInfo {
                switch feedback {
                case .next, .previous, .restarted: self.refreshTrack()
                default: break
                }
            }
            if self.pendingCommands == 0 { self.hud.show(room: room, feedback: feedback) }
        }
        keys.onError = { [weak self, weak keys] message in
            guard let self = self, let keys = keys, self.listener === keys else { return }
            self.pendingCommands -= 1
            self.error = message
            if self.pendingCommands == 0 { self.hud.show(room: room, feedback: .failed) }
        }
        do {
            try keys.start()
            listener = keys
            enabled = true
            defaults.set(true, forKey: "enabled")
        } catch {
            keys.stop()
            permissionPage = MediaKeys.permissionPage
            if permissionPage == "Privacy_Accessibility" {
                self.error = "Accessibility access is missing for this build. Allow Sonos Keys, then retry."
            } else if permissionPage == "Privacy_ListenEvent" {
                self.error = "Input Monitoring access is missing for this build. Allow Sonos Keys, then restart the app."
            } else {
                self.error = error.localizedDescription
            }
            if permissionPage != nil { openPermissionSettings() }
        }
    }

    func openPermissionSettings() {
        guard let page = permissionPage,
              let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?" + page) else { return }
        NSWorkspace.shared.open(url)
    }

    func retryMediaKeys() {
        stop()
        enable()
    }

    func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled || status == .requiresApproval
        loginApprovalRequired = status == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = error.localizedDescription
        }
        refreshLoginStatus()
        if loginApprovalRequired { SMAppService.openSystemSettingsLoginItems() }
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    func attachStatusButton(_ button: NSStatusBarButton) {
        hud.anchorRect = { [weak button] in
            guard let button = button, let window = button.window else { return nil }
            return window.convertToScreen(button.convert(button.bounds, to: nil))
        }
    }

    func stop() {
        listener?.stop()
        listener = nil
        pendingCommands = 0
        hud.hide()
        enabled = false
    }

    func quit() {
        stop()
        NSApp.terminate(nil)
    }
}
