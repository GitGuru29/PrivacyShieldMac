import AppKit

class ShieldManager {
    private var windows: [NSWindow] = []
    private var isShieldVisible = false
    
    init() {
        // Don't create windows in init - wait until they're actually needed
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func screenParametersChanged() {
        rebuildWindows()
        if isShieldVisible {
            showShield()
        }
    }
    
    private func rebuildWindows() {
        // Close and release all existing windows
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        
        for screen in NSScreen.screens {
            let overlayWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: true // defer creation until needed
            )
            
            overlayWindow.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
            overlayWindow.backgroundColor = .clear
            overlayWindow.isOpaque = false
            overlayWindow.ignoresMouseEvents = false
            overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
            visualEffectView.autoresizingMask = [.width, .height]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            
            overlayWindow.contentView = visualEffectView
            
            windows.append(overlayWindow)
        }
    }
    
    func showShield() {
        if windows.isEmpty {
            rebuildWindows()
        }
        guard !isShieldVisible else { return }
        isShieldVisible = true
        
        for window in windows {
            window.orderFrontRegardless()
        }
    }
    
    func hideShield() {
        guard isShieldVisible else { return }
        isShieldVisible = false
        
        for window in windows {
            window.orderOut(nil)
        }
    }
    
    func toggleShield() {
        if isShieldVisible {
            hideShield()
        } else {
            showShield()
        }
    }
}
