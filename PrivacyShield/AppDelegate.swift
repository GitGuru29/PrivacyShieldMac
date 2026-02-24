import AppKit
import Foundation
import Carbon.HIToolbox
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var cameraManager: CameraManager?
    var faceDetector: FaceDetector?
    var shieldManager: ShieldManager?
    private var hotKeyRef: EventHotKeyRef?
    
    // Settings
    var sensitivityThreshold: Float {
        get { UserDefaults.standard.float(forKey: "matchThreshold").isZero ? 0.6 : UserDefaults.standard.float(forKey: "matchThreshold") }
        set { UserDefaults.standard.set(newValue, forKey: "matchThreshold") }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Disable App Nap so camera + detection stays active in background
        ProcessInfo.processInfo.disableAutomaticTermination("Privacy Shield active")
        let _ = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Monitoring camera for privacy")
        
        setupMenu()
        registerGlobalHotKey()
        requestNotificationPermission()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startPrivacyShield()
        }
    }
    
    private func startPrivacyShield() {
        let shield = ShieldManager()
        self.shieldManager = shield
        
        let detector = FaceDetector(shieldManager: shield, delegate: self)
        self.faceDetector = detector
        
        let camera = CameraManager(delegate: detector)
        self.cameraManager = camera
        
        camera.checkPermissionAndStart()
        updateMenuIcon(safe: true)
    }

    // MARK: - Menu Bar
    
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
        rebuildMenu()
    }
    
    private func rebuildMenu() {
        let menu = NSMenu()
        
        // Status
        let statusItem = NSMenuItem(title: "Status: Initializing…", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        
        // Enrollment
        let enrollItem = NSMenuItem(title: "Enroll My Face", action: #selector(enrollFace), keyEquivalent: "e")
        enrollItem.target = self
        menu.addItem(enrollItem)
        
        let addUserItem = NSMenuItem(title: "Add Trusted Face", action: #selector(addTrustedFace), keyEquivalent: "")
        addUserItem.target = self
        menu.addItem(addUserItem)
        
        let resetItem = NSMenuItem(title: "Reset All Enrollments", action: #selector(resetEnrollment), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Detection Range
        let rangeMenu = NSMenu()
        let rangeLabels: [(String, Float)] = [
            ("1 foot", 0.35),
            ("2 feet", 0.25),
            ("4 feet", 0.15),
            ("6 feet", 0.08),
        ]
        let currentMin = UserDefaults.standard.float(forKey: "minFaceSize")
        for (label, value) in rangeLabels {
            let item = NSMenuItem(title: label, action: #selector(setDetectionRange(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(value * 1000)
            item.representedObject = value
            let isSelected = (currentMin == 0 && value == 0.25) || abs(currentMin - value) < 0.01
            item.state = isSelected ? .on : .off
            rangeMenu.addItem(item)
        }
        let rangeItem = NSMenuItem(title: "Detection Range", action: nil, keyEquivalent: "")
        rangeItem.submenu = rangeMenu
        menu.addItem(rangeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle
        let toggleItem = NSMenuItem(title: "Toggle Shield (⌘⇧L)", action: #selector(toggleShield), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = isLaunchAtLoginEnabled() ? .on : .off
        launchItem.tag = 200
        menu.addItem(launchItem)
        
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Privacy Shield", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem.menu = menu
    }
    
    func updateMenuIcon(safe: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusItem.button else { return }
            let symbolName = safe ? "eye" : "eye.slash.fill"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Privacy Shield") {
                image.isTemplate = true
                button.image = image
            }
            // Update status text in menu
            if let menu = self?.statusItem.menu, let item = menu.item(withTag: 100) {
                item.title = safe ? "Status: ✅ Owner detected" : "Status: ⚠️ Shield active"
            }
        }
    }
    
    // MARK: - Actions
    
    @objc func enrollFace() {
        guard let detector = faceDetector else { return }
        Toast.show(message: "Look at the camera… Enrolling your face", duration: 3)
        detector.startEnrollment(userLabel: "owner") { success in
            if success {
                Toast.show(message: "✅ Face enrolled successfully!", duration: 2)
            } else {
                Toast.show(message: "❌ Enrollment failed — make sure your face is visible", duration: 2)
            }
        }
    }
    
    @objc func addTrustedFace() {
        guard let detector = faceDetector else { return }
        Toast.show(message: "Ask the trusted person to look at the camera…", duration: 3)
        detector.startEnrollment(userLabel: "trusted_\(Int.random(in: 1000...9999))") { success in
            if success {
                Toast.show(message: "✅ Trusted face added!", duration: 2)
            } else {
                Toast.show(message: "❌ Failed — make sure their face is visible", duration: 2)
            }
        }
    }
    
    @objc func resetEnrollment() {
        faceDetector?.faceRecognizer.resetAllEnrollments()
        Toast.show(message: "All enrollments reset", duration: 2)
    }
    
    @objc func toggleShield() {
        shieldManager?.toggleShield()
    }
    
    @objc func setDetectionRange(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Float else { return }
        faceDetector?.minFaceSize = CGFloat(value)
        
        // Update checkmarks
        if let rangeMenu = sender.menu {
            for item in rangeMenu.items {
                item.state = (item === sender) ? .on : .off
            }
        }
        
        let label = sender.title
        Toast.show(message: "Detection range: \(label)", duration: 1.5)
    }
    
    // MARK: - Global Hotkey (⌘⇧L)
    
    private func registerGlobalHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x50535F48) // "PS_H"
        hotKeyID.id = 1
        
        // ⌘⇧L: cmdKey + shiftKey + kVK_ANSI_L
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_L)
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            print("Global hotkey ⌘⇧L registered")
        } else {
            print("Failed to register global hotkey: \(status)")
        }
        
        // Install handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            appDelegate.toggleShield()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
    }
    
    // MARK: - Launch at Login
    
    @objc func toggleLaunchAtLogin() {
        let enabled = isLaunchAtLoginEnabled()
        setLaunchAtLogin(!enabled)
        if let menu = statusItem.menu, let item = menu.item(withTag: 200) {
            item.state = !enabled ? .on : .off
        }
    }
    
    private func isLaunchAtLoginEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "launchAtLogin")
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")
        // For a proper implementation use SMAppService on macOS 13+ or SMLoginItemSetEnabled
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login item error: \(error)")
            }
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            print("Notification permission: \(granted)")
        }
    }
    
    func sendStrangerNotification() {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Privacy Shield"
        content.body = "An unrecognized face was detected. Screen has been blurred."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "stranger_\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

import ServiceManagement

extension AppDelegate: FaceDetectorDelegate {}
