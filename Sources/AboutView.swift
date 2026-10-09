import SwiftUI
import AppKit

struct AboutView: View {
    @ObservedObject var updates: UpdateChecker
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
            VStack(spacing: 6) {
                Text("Sonos Keys").font(.title.weight(.semibold))
                Text("Version \(version)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Your media keys, your Sonos room.")
                .foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Button("Check for Updates", action: updates.check)
                    .buttonStyle(.bordered)
                    .disabled(updates.checking)
                Text(updates.status ?? "")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(minHeight: 28)
            }
            Divider().padding(.horizontal, 24)
            Text("© 2026 Michael Teeuw")
                .font(.subheadline)
            Button("Xonay Media") {
                NSWorkspace.shared.open(URL(string: "https://xonaymedia.nl")!)
            }
            .buttonStyle(.bordered)
            Text("For non-commercial use only.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(width: 360)
    }
}
