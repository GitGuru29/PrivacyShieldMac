import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var cameraManager: CameraManager!
    var faceDetector: FaceDetector!
    var shieldManager: ShieldManager!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenu()
        
        shieldManager = ShieldManager()
        faceDetector = FaceDetector(shieldManager: shieldManager)
        cameraManager = CameraManager(delegate: faceDetector)
        
        cameraManager.checkPermissionAndStart()
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

        let enrollItem = NSMenuItem(title: "Enroll Owner Face", action: #selector(enrollOwner), keyEquivalent: "e")
        enrollItem.target = self
        menu.addItem(enrollItem)

        let resetItem = NSMenuItem(title: "Reset Enrollment", action: #selector(resetEnrollment), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Shield", action: #selector(toggleShield), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem(title: "Quit Privacy Shield", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }
    
    @objc func toggleShield() {
        shieldManager?.toggleShield()
    }

    @objc func enrollOwner() {
        // Start or trigger an enrollment flow. The underlying manager should handle capturing a few frames and storing a local template.
        shieldManager?.startEnrollment { [weak self] (success: Bool, error: Error?) in
            if success {
                Toast.show(message: "Owner enrolled", duration: 2)
            } else {
                Toast.show(message: "Enrollment failed", duration: 2)
                if let error = error { print("Enrollment error: \(error)") }
            }
        }
    }

    @objc func resetEnrollment() {
        shieldManager?.resetEnrollment()
        Toast.show(message: "Enrollment reset", duration: 2)
    }
}

