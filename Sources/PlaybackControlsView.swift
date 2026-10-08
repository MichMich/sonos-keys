import SwiftUI

struct PlaybackControlsView: View {
    let state: SonosControls?
    let busy: Bool
    let error: String?
    let perform: (String, Int?) -> Void
    @State private var volume = 0.0
    @State private var editingVolume = false

    var body: some View {
        PanelSection(background: .black.opacity(0.12), padding: 12, topDivider: true) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    button("Previous", icon: "backward.end.fill", available: state?.canPrevious == true, command: "previous")
                    button(state?.playing == true ? "Pause" : "Play", icon: state?.playing == true ? "pause.fill" : "play.fill",
                           available: state?.canPlayPause == true, command: "play")
                    button("Next", icon: "forward.end.fill", available: state?.canNext == true, command: "next")
                    button("Mute", icon: state?.muted == true ? "speaker.slash.fill" : "speaker.wave.2.fill",
                           available: state?.muted != nil, command: "mute")
                    Slider(value: $volume, in: 0...100) { editing in
                        editingVolume = editing
                        if !editing { perform("volume", Int(volume)) }
                    }
                    .controlSize(.small)
                    .disabled(state?.volume == nil)
                    .accessibilityLabel("Sonos volume")
                    .help("Volume: \(Int(volume))%")
                    .padding(.leading, 6)
                }
                .allowsHitTesting(!busy)
                if let error = error {
                    Text(error).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 6)
        }
        .onAppear { volume = Double(state?.volume ?? 0) }
        .onChange(of: state?.volume) { level in
            if !editingVolume { volume = Double(level ?? 0) }
        }
    }

    private func button(_ title: String, icon: String, available: Bool, command: String) -> some View {
        Button { perform(command, nil) } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
                .opacity(available ? 1 : 0.3)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .help(title)
        .accessibilityLabel(title)
    }
}
