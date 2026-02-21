import AppKit
import QuartzCore

final class Toast: NSObject {
    private static var toastWindow: NSWindow?

    static func show(message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            // Remove any existing toast
            if let window = toastWindow {
                window.orderOut(nil)
                toastWindow = nil
            }

            let padding: CGFloat = 12
            let maxWidth: CGFloat = 360

            let label = NSTextField(labelWithString: message)
            label.textColor = .white
            label.backgroundColor = .clear
            label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 3
            label.alignment = .center

            let textSize = label.attributedStringValue.boundingRect(with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin])
            let contentSize = NSSize(width: ceil(textSize.width) + padding * 2, height: ceil(textSize.height) + padding * 2)

            let contentView = NSView(frame: NSRect(origin: .zero, size: contentSize))
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 12
            contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor

            label.frame = NSRect(x: padding, y: padding, width: contentSize.width - padding * 2, height: contentSize.height - padding * 2)
            contentView.addSubview(label)

            let screen = NSScreen.main ?? NSScreen.screens.first!
            let margin: CGFloat = 20
            let origin = CGPoint(x: screen.visibleFrame.maxX - contentSize.width - margin,
                                 y: screen.visibleFrame.maxY - contentSize.height - margin)

            let window = NSWindow(contentRect: NSRect(origin: origin, size: contentSize),
                                  styleMask: [.borderless],
                                  backing: .buffered,
                                  defer: false,
                                  screen: screen)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .statusBar
            window.ignoresMouseEvents = true
            window.contentView = contentView
            window.alphaValue = 0

            window.makeKeyAndOrderFront(nil)
            toastWindow = window

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                window.animator().alphaValue = 1.0
            } completionHandler: {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.15
                        window.animator().alphaValue = 0
                    } completionHandler: {
                        window.orderOut(nil)
                        if toastWindow === window { toastWindow = nil }
                    }
                }
            }
        }
    }
}
