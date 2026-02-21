import AppKit
import Foundation

class ShieldManager {
    private var windows: [NSWindow] = []
    
    init() {
        setupWindows()
        
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    @objc private func screenParametersChanged() {
        setupWindows()
    }
    
    private func setupWindows() {
        for window in windows {
            window.close()
        }
        windows.removeAll()
        
        for screen in NSScreen.screens {
            let overlayWindow = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            
            overlayWindow.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
            overlayWindow.backgroundColor = .clear
            overlayWindow.isOpaque = false
            
            // Allow user to click through the blur?
            // If we block clicks, we secure the app, but they can't do anything until faces decrease. Let's block clicks.
            overlayWindow.ignoresMouseEvents = false
            
            overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let visualEffectView = NSVisualEffectView(frame: overlayWindow.contentView!.bounds)
            visualEffectView.autoresizingMask = [.width, .height]
            visualEffectView.material = .hudWindow // Gives a nice dark blurred effect
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            
            overlayWindow.contentView?.addSubview(visualEffectView)
            
            windows.append(overlayWindow)
        }
    }
    
    func showShield() {
        for window in windows {
            if !window.isVisible {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true) // To make sure it stays on top easily
            }
        }
    }
    
    func hideShield() {
        for window in windows {
            if window.isVisible {
                window.orderOut(nil)
            }
        }
    }
    
    func toggleShield() {
        if let first = windows.first, first.isVisible {
            hideShield()
        } else {
            showShield()
        }
    }
    
    // MARK: - Enrollment (stubs)
    typealias EnrollmentCompletion = (_ success: Bool, _ error: Error?) -> Void

    /// Starts an owner face enrollment flow. This is a stub implementation that instantly succeeds.
    /// Replace with logic to capture frames and persist an owner face template.
    func startEnrollment(completion: @escaping EnrollmentCompletion) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion(true, nil)
        }
    }

    /// Resets any stored enrollment/template. Stub implementation.
    func resetEnrollment() {
        // TODO: Delete any stored template from disk/keychain when implemented.
        print("Enrollment reset (stub)")
    }
}
