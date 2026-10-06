import AppKit
import ApplicationServices

final class MediaKeys {
    static let modifiers: [(name: String, symbol: String, flag: NSEvent.ModifierFlags)] = [
        ("Command", "⌘", .command),
        ("Option", "⌥", .option),
        ("Control", "⌃", .control),
        ("Shift", "⇧", .shift),
        ("Fn / Globe", "fn", .function),
        ("Caps Lock", "⇪", .capsLock)
    ]

    private let requiredModifiers: NSEvent.ModifierFlags
    private let sonos: Sonos
    private let worker = DispatchQueue(label: "sonos-keys.network")
    private var consumed = Set<Int>()
    private var volumePending = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private let commands = [0: "up", 1: "down", 7: "mute", 16: "play", 17: "next", 18: "previous", 19: "next", 20: "previous"]

    var onDiscoveryError: ((String) -> Void)?
    var onPending: ((Bool) -> Void)?
    var onFeedback: ((SonosFeedback) -> Void)?
    var onError: ((String) -> Void)?

    init(_ sonos: Sonos, modifiers: NSEvent.ModifierFlags) {
        self.sonos = sonos
        self.requiredModifiers = modifiers
    }

    func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            consumed.removeAll()
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let native = NSEvent(cgEvent: event), native.type == .systemDefined, native.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }
        let code = (native.data1 >> 16) & 0xffff
        let state = (native.data1 >> 8) & 0xff
        let repeated = native.data1 & 1 != 0
        guard let command = commands[code] else { return Unmanaged.passUnretained(event) }
        if state == 0x0b {
            if consumed.remove(code) != nil { return nil }
            return Unmanaged.passUnretained(event)
        }
        guard state == 0x0a else { return Unmanaged.passUnretained(event) }
        if !repeated {
            guard !requiredModifiers.isEmpty && native.modifierFlags.contains(requiredModifiers) else { return Unmanaged.passUnretained(event) }
            consumed.insert(code)
        }
        guard consumed.contains(code) else { return Unmanaged.passUnretained(event) }
        if !repeated || command == "up" || command == "down" {
            let volume = command == "up" || command == "down"
            if volume && volumePending { return nil }
            if volume { volumePending = true }
            onPending?(volume)
            let feedback = onFeedback
            let failure = onError
            worker.async { [sonos] in
                do {
                    let result = try sonos.perform(command)
                    DispatchQueue.main.async { [weak self] in
                        if volume { self?.volumePending = false }
                        feedback?(result)
                    }
                } catch {
                    let message = error.localizedDescription
                    DispatchQueue.main.async { [weak self] in
                        if volume { self?.volumePending = false }
                        failure?(message)
                    }
                }
            }
        }
        return nil
    }

    static var permissionPage: String? {
        if !AXIsProcessTrusted() { return "Privacy_Accessibility" }
        if !CGPreflightListenEventAccess() { return "Privacy_ListenEvent" }
        return nil
    }

    func start() throws {
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context = context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<MediaKeys>.fromOpaque(context).takeUnretainedValue().handle(type, event)
        }
        let mask = CGEventMask(1) << NSEvent.EventType.systemDefined.rawValue
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw Failure(message: "Cannot capture media keys. Allow Accessibility and Input Monitoring for SonosKeys in System Settings, then restart it.")
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)!
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        let discoveryError = onDiscoveryError
        worker.async { [sonos] in
            do { try sonos.refreshTopology() }
            catch {
                let message = error.localizedDescription
                DispatchQueue.main.async { discoveryError?(message) }
            }
        }
    }
    func stop() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        consumed.removeAll()
    }
}

