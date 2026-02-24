import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var cameraManager: CameraManager?
    var faceDetector: FaceDetector?
    var shieldManager: ShieldManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenu()
        
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
        
        // Update menu to show enrollment status
        updateEnrollmentStatus()
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
        
        let enrollItem = NSMenuItem(title: "Enroll My Face", action: #selector(enrollFace), keyEquivalent: "e")
        enrollItem.target = self
        menu.addItem(enrollItem)
        
        let resetItem = NSMenuItem(title: "Reset Enrollment", action: #selector(resetEnrollment), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Shield", action: #selector(toggleShield), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Privacy Shield", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }
    
    @objc func enrollFace() {
        guard let detector = faceDetector else { return }
        
        Toast.show(message: "Look at the camera... Enrolling your face", duration: 3)
        
        detector.startEnrollment { success in
            if success {
                Toast.show(message: "✅ Face enrolled successfully!", duration: 2)
            } else {
                Toast.show(message: "❌ Enrollment failed", duration: 2)
            }
        }
    }
    
    @objc func resetEnrollment() {
        faceDetector?.faceRecognizer.resetEnrollment()
        Toast.show(message: "Enrollment reset", duration: 2)
    }
    
    @objc func toggleShield() {
        shieldManager?.toggleShield()
    }
    
    private func updateEnrollmentStatus() {
        if let detector = faceDetector, detector.faceRecognizer.isEnrolled {
            print("Owner face is enrolled")
        } else {
            print("No face enrolled — use menu to enroll")
        }
    }
}
