import AppKit
import SwiftUI
import QuartzCore

final class SonosHUD {
    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?
    private var loading: DispatchWorkItem?
    private var generation = 0
    var anchorRect: (() -> NSRect?)?
    var onVisibilityChange: ((Bool) -> Void)?
    var beforePresentation: ((@escaping () -> Void) -> Void)?
    let trackInfo = HUDTrackInfo()

    func show(room: String, feedback: SonosFeedback) {
        loading?.cancel()
        dismissal?.cancel()
        generation += 1
        let currentGeneration = generation
        if case .loading = feedback {
            let loading = DispatchWorkItem { [weak self] in
                guard let self = self, self.generation == currentGeneration else { return }
                self.present(room: room, feedback: feedback, generation: currentGeneration)
            }
            self.loading = loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: loading)
        } else {
            present(room: room, feedback: feedback, generation: currentGeneration)
        }
    }

    private func present(room: String, feedback: SonosFeedback, generation currentGeneration: Int) {
        let present = { [weak self] in
            guard let self = self, self.generation == currentGeneration else { return }
            self.render(room: room, feedback: feedback, generation: currentGeneration)
        }
        if let beforePresentation = beforePresentation { beforePresentation(present) }
        else { present() }
    }

    private func render(room: String, feedback: SonosFeedback, generation currentGeneration: Int) {
        guard let anchor = anchorRect?() else { return }
        let hiddenMenuBar = !NSMenu.menuBarVisible()
        var height: CGFloat
        switch feedback {
        case .volume: height = 120
        case .loading(let volume): height = volume ? 120 : 94
        default: height = 94
        }
        if trackInfo.enabled { height += 82 }
        if hiddenMenuBar { height -= 10 }

        if panel == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .popUpMenu
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.canHide = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.panel = panel
        }
        guard let panel = panel else { return }
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) }) ?? NSScreen.main
        let frame = screen?.visibleFrame ?? anchor
        let x = min(frame.maxX - 308, max(frame.minX + 8, anchor.midX - 150))
        let arrowX: CGFloat? = hiddenMenuBar ? nil : min(274, max(26, anchor.midX - x))
        let top = hiddenMenuBar ? (screen?.frame.maxY ?? anchor.maxY) - (screen?.safeAreaInsets.top ?? 0) - 8 : anchor.minY - 4
        let targetFrame = NSRect(x: x, y: top - height, width: 300, height: height)
        let visible = panel.isVisible
        if !visible { panel.setFrame(targetFrame, display: false) }
        let view = HUDView(room: room, feedback: feedback, arrowX: arrowX, trackInfo: trackInfo)
        if let hostingView = panel.contentView as? NSHostingView<HUDView> {
            hostingView.rootView = view
        } else {
            panel.contentView = NSHostingView(rootView: view)
        }
        if !panel.isVisible { panel.alphaValue = 0 }
        onVisibilityChange?(true)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            if visible && panel.frame != targetFrame { panel.animator().setFrame(targetFrame, display: true) }
            panel.animator().alphaValue = 1
        }
        dismissal?.cancel()
        if case .loading = feedback { return }
        let dismissal = DispatchWorkItem { [weak self, weak panel] in
            guard let self = self, let panel = panel, self.generation == currentGeneration else { return }
            PanelAnimation.close(panel) { [weak self, weak panel] in
                if self?.generation == currentGeneration {
                    panel?.orderOut(nil)
                    self?.onVisibilityChange?(false)
                }
            }
        }
        self.dismissal = dismissal
        let duration: TimeInterval
        switch feedback {
        case .next, .previous, .restarted: duration = trackInfo.enabled ? 3 : 1.5
        default: duration = 1.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismissal)
    }
    func hide(completion: (() -> Void)? = nil) {
        generation += 1
        loading?.cancel()
        dismissal?.cancel()
        if let completion = completion, let panel = panel, panel.isVisible {
            let currentGeneration = generation
            PanelAnimation.close(panel) { [weak self, weak panel] in
                guard let self = self, self.generation == currentGeneration else { return }
                panel?.orderOut(nil)
                self.onVisibilityChange?(false)
                completion()
            }
            return
        }
        panel?.orderOut(nil)
        onVisibilityChange?(false)
        completion?()
    }
}

final class HUDTrackInfo: ObservableObject {
    @Published var enabled = false
    @Published var track: SonosTrack?
}

private struct HUDView: View {
    let room: String
    let feedback: SonosFeedback
    let arrowX: CGFloat?
    @ObservedObject var trackInfo: HUDTrackInfo

    private var hasVolumeBar: Bool {
        switch feedback {
        case .volume: return true
        case .loading(let volume): return volume
        default: return false
        }
    }

    private var presentation: (title: String, symbol: String, volume: Int?) {
        switch feedback {
        case .loading: return ("Updating…", "", nil)
        case .failed: return ("Command failed", "exclamationmark.triangle.fill", nil)
        case .volume(let volume):
            return ("\(volume)%", volume == 0 ? "speaker.fill" : "speaker.wave.2.fill", volume)
        case .playing: return ("Playing", "play.fill", nil)
        case .paused: return ("Paused", "pause.fill", nil)
        case .next: return ("Next track", "forward.end.fill", nil)
        case .previous: return ("Previous track", "backward.end.fill", nil)
        case .previousUnavailable: return ("Previous unavailable", "backward.end.fill", nil)
        case .restarted: return ("Track restarted", "arrow.counterclockwise", nil)
        case .muted(let muted):
            return (muted ? "Muted" : "Unmuted", muted ? "speaker.slash.fill" : "speaker.wave.2.fill", nil)
        }
    }

    var body: some View {
        let content = presentation
        VStack(spacing: 0) {
            PanelSection {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        IconTile {
                            if case .loading = feedback {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: content.symbol)
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(room)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(content.title)
                                .font(.system(size: 19, weight: .semibold))
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    if hasVolumeBar {
                        GeometryReader { geometry in
                            Capsule().fill(Color.primary.opacity(0.1))
                            Capsule().fill(Color.accentColor)
                                .frame(width: geometry.size.width * CGFloat(min(100, max(0, content.volume ?? 0))) / 100)
                        }
                        .frame(height: 5)
                        .opacity(content.volume == nil ? 0 : 1)
                    }
                }
            }
            .frame(height: hasVolumeBar ? 110 : 84)
            if trackInfo.enabled {
                TrackInfoView(track: trackInfo.track)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, arrowX == nil ? 0 : 10)
        .background(.regularMaterial, in: HUDShape(arrowX: arrowX))
        .clipShape(HUDShape(arrowX: arrowX))
        .overlay {
            HUDShape(arrowX: arrowX)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct HUDShape: Shape {
    let arrowX: CGFloat?

    func path(in rect: CGRect) -> Path {
        let top: CGFloat = arrowX == nil ? 0 : 10
        let radius: CGFloat = 20
        let width = rect.width
        let height = rect.height
        var path = Path()
        path.move(to: CGPoint(x: radius, y: top))
        if let arrowX = arrowX {
            path.addLine(to: CGPoint(x: arrowX - 8, y: top))
            path.addLine(to: CGPoint(x: arrowX, y: 0))
            path.addLine(to: CGPoint(x: arrowX + 8, y: top))
        }
        path.addLine(to: CGPoint(x: width - radius, y: top))
        path.addQuadCurve(to: CGPoint(x: width, y: top + radius), control: CGPoint(x: width, y: top))
        path.addLine(to: CGPoint(x: width, y: height - radius))
        path.addQuadCurve(to: CGPoint(x: width - radius, y: height), control: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: radius, y: height))
        path.addQuadCurve(to: CGPoint(x: 0, y: height - radius), control: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: top + radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: top), control: CGPoint(x: 0, y: top))
        path.closeSubpath()
        return path
    }
}
