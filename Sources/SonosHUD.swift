import AppKit
import SwiftUI
import QuartzCore

final class SonosHUD {
    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?
    private var loading: DispatchWorkItem?
    private var generation = 0
    var anchorRect: (() -> NSRect?)?

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
        guard let anchor = anchorRect?() else { return }
        let height: CGFloat
        switch feedback {
        case .volume: height = 120
        case .loading(let volume): height = volume ? 120 : 94
        default: height = 94
        }

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
        let arrowX = min(274, max(26, anchor.midX - x))
        let targetFrame = NSRect(x: x, y: anchor.minY - height - 4, width: 300, height: height)
        let visible = panel.isVisible
        if !visible { panel.setFrame(targetFrame, display: false) }
        panel.contentView = NSHostingView(rootView: HUDView(room: room, feedback: feedback, arrowX: arrowX))
        if !panel.isVisible { panel.alphaValue = 0 }
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
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self, weak panel] in
                if self?.generation == currentGeneration { panel?.orderOut(nil) }
            })
        }
        self.dismissal = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: dismissal)
    }
    func hide() {
        generation += 1
        loading?.cancel()
        dismissal?.cancel()
        panel?.orderOut(nil)
    }
}

private struct HUDView: View {
    let room: String
    let feedback: SonosFeedback
    let arrowX: CGFloat

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
        case .muted(let muted):
            return (muted ? "Muted" : "Unmuted", muted ? "speaker.slash.fill" : "speaker.wave.2.fill", nil)
        }
    }

    var body: some View {
        let content = presentation
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor.opacity(0.12))
                    if case .loading = feedback {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: content.symbol)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 46, height: 46)
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
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 10)
        .background(.regularMaterial, in: HUDShape(arrowX: arrowX))
        .overlay {
            HUDShape(arrowX: arrowX)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct HUDShape: Shape {
    let arrowX: CGFloat

    func path(in rect: CGRect) -> Path {
        let top: CGFloat = 10
        let radius: CGFloat = 20
        let width = rect.width
        let height = rect.height
        var path = Path()
        path.move(to: CGPoint(x: radius, y: top))
        path.addLine(to: CGPoint(x: arrowX - 8, y: top))
        path.addLine(to: CGPoint(x: arrowX, y: 0))
        path.addLine(to: CGPoint(x: arrowX + 8, y: top))
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
