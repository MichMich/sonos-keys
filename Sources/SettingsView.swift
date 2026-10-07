import SwiftUI
import AppKit
import Darwin

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var loaded = false
    @State private var room = ""
    @State private var speakerIP = ""
    @State private var manual = false
    @State private var inverted = false
    @State private var volumeStep = 2
    @State private var modifiers: NSEvent.ModifierFlags = .command

    private var roomChoices: [String] {
        Array(Set(model.rooms + (room.isEmpty ? [] : [room]))).sorted()
    }

    private func close() {
        if let onClose = onClose { onClose() }
        else { dismiss() }
    }

    private func applySettings() {
        guard loaded else { return }
        var ip = ""
        if manual {
            ip = speakerIP.trimmingCharacters(in: .whitespacesAndNewlines)
            var address = in_addr()
            if inet_pton(AF_INET, ip, &address) != 1 { ip = model.speakerIP }
        }
        model.save(room: room, speakerIP: ip, volumeStep: volumeStep, modifiers: modifiers, inverted: inverted)
    }

    private var volumeBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(1...20, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(step <= volumeStep ? Color.accentColor : Color.secondary.opacity(0.2))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                volumeStep = min(20, max(1, Int(value.location.x / geometry.size.width * 20) + 1))
            })
        }
        .frame(height: 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Volume step")
        .accessibilityValue("\(volumeStep)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: volumeStep = min(20, volumeStep + 1)
            case .decrement: volumeStep = max(1, volumeStep - 1)
            @unknown default: break
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "hifispeaker.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sonos Keys").font(.title2.weight(.semibold))
                            Text("Your media keys, your Sonos room.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Room").fontWeight(.medium)
                                Spacer()
                                Toggle("Manual", isOn: $manual)
                                    .toggleStyle(.checkbox)
                                if model.discovering { ProgressView().controlSize(.small) }
                                Button { model.discoverRooms(speakerIP: manual ? speakerIP : "") } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .help("Refresh Sonos rooms")
                                .disabled(model.discovering || (manual && speakerIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                            }
                            if manual {
                                HStack {
                                    Text("Speaker IP")
                                    TextField("192.168.1.100", text: $speakerIP)
                                        .textFieldStyle(.roundedBorder)
                                        .accessibilityLabel("Speaker IP")
                                }
                                Text("Enter any Sonos speaker's IPv4 address, then click Refresh.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Picker("Sonos room", selection: $room) {
                                Text("Choose a room").tag("")
                                ForEach(roomChoices, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            if let error = model.discoveryError {
                                Text(error).font(.caption).foregroundStyle(.red)
                            } else if !model.discovering && model.rooms.isEmpty {
                                Text("No rooms found. Check that Sonos is on your local network.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Divider()
                            HStack {
                                Text("Volume step").fontWeight(.medium)
                                Spacer()
                                Text("\(volumeStep)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            volumeBar
                            HStack {
                                Text("1")
                                Spacer()
                                Text("Drag to change the step")
                                Spacer()
                                Text("20")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Modifier keys").fontWeight(.medium)
                            Text(inverted
                                 ? "Hold all selected keys with a media key to control your Mac."
                                 : "Hold all selected keys with a media key to control Sonos.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 12) {
                                ForEach(MediaKeys.modifiers.indices, id: \.self) { index in
                                    let key = MediaKeys.modifiers[index]
                                    Toggle("\(key.symbol)  \(key.name)", isOn: Binding(
                                        get: { modifiers.contains(key.flag) },
                                        set: { selected in
                                            if selected { modifiers.insert(key.flag) }
                                            else if MediaKeys.modifiers.filter({ modifiers.contains($0.flag) }).count > 1 { modifiers.remove(key.flag) }
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                }
                            }
                            Divider()
                            Toggle("Control Sonos by default", isOn: $inverted)
                                .toggleStyle(.switch)
                            Text(inverted
                                 ? "Media keys alone → Sonos\nSelected modifiers + media keys → Mac"
                                 : "Media keys alone → Mac\nSelected modifiers + media keys → Sonos")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Select at least one key. Caps Lock uses its on/off state. Fn depends on your keyboard.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(8)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Track info").fontWeight(.medium)
                            Toggle("Show in media-key HUD", isOn: Binding(
                                get: { model.showTrackInfoInHUD },
                                set: { model.setShowTrackInfo(inHUD: $0, inMenu: model.showTrackInfoInMenu) }
                            ))
                            .toggleStyle(.switch)
                            Toggle("Show in menu", isOn: Binding(
                                get: { model.showTrackInfoInMenu },
                                set: { model.setShowTrackInfo(inHUD: model.showTrackInfoInHUD, inMenu: $0) }
                            ))
                            .toggleStyle(.switch)
                            Text("Choose where to show the cover and track details. Turn both off to stop updates.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Divider()
                            Toggle("Launch at login", isOn: Binding(
                                get: { model.launchAtLogin },
                                set: { model.setLaunchAtLogin($0) }
                            ))
                            .toggleStyle(.switch)
                            Text("Open Sonos Keys when you sign in to your Mac.")
                                .font(.caption).foregroundStyle(.secondary)
                            if model.loginApprovalRequired {
                                Button("Allow in Login Items…") { model.openLoginSettings() }
                            }
                            if let error = model.loginError {
                                Text(error).font(.caption).foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }

                    if let error = model.error {
                        PanelSection(background: .orange.opacity(0.05)) {
                            ErrorView(
                                title: model.permissionPage == nil ? "Sonos Keys needs attention" : "Allow media-key access",
                                message: error,
                                actions: model.permissionPage == nil ? [] : [
                                    .init(title: "Privacy Settings", icon: "lock.shield", perform: model.openPermissionSettings),
                                    .init(title: "Retry media keys", icon: "arrow.clockwise", perform: model.retryMediaKeys)
                                ]
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Text("Changes apply immediately.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Close") { close() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 440, height: min(640, (NSScreen.main?.visibleFrame.height ?? 740) - 100))
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.refreshLoginStatus() }
        }
        .onChange(of: room) { _ in applySettings() }
        .onChange(of: speakerIP) { _ in applySettings() }
        .onChange(of: manual) { _ in applySettings() }
        .onChange(of: volumeStep) { _ in applySettings() }
        .onChange(of: modifiers) { _ in applySettings() }
        .onChange(of: inverted) { _ in applySettings() }
        .onAppear {
            room = model.room
            speakerIP = model.speakerIP
            manual = !model.speakerIP.isEmpty
            volumeStep = model.volumeStep
            modifiers = model.modifiers
            inverted = model.inverted
            model.refreshLoginStatus()
            loaded = true
            model.discoverRooms(speakerIP: speakerIP)
        }
    }
}
