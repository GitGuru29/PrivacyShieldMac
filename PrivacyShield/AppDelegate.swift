import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var cameraManager: CameraManager?
    var faceDetector: FaceDetector?
    var shieldManager: ShieldManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenu()
        
        // Delay camera setup slightly to ensure the app is fully launched
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startPrivacyShield()
        }
    }
    
    private func startPrivacyShield() {
        let shield = ShieldManager()
        self.shieldManager = shield
        
        let detector = FaceDetector(shieldManager: shield)
        self.faceDetector = detector
        
        let camera = CameraManager(delegate: detector)
        self.cameraManager = camera
        
        camera.checkPermissionAndStart()
    }

    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Privacy Shield") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Shield"
            }
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle Shield", action: #selector(toggleShield), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Privacy Shield", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }
    
    @objc func toggleShield() {
        shieldManager?.toggleShield()
    }
}
