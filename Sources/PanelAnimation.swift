import AppKit
import QuartzCore

enum PanelAnimation {
    static func close(_ window: NSWindow, completion: @escaping () -> Void) {
        let frame = window.frame
        let size = NSSize(width: frame.width * 0.96, height: frame.height * 0.96)
        let target = NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height,
                            width: size.width, height: size.height)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(target, display: true)
            window.animator().alphaValue = 0
        }, completionHandler: completion)
    }
}
