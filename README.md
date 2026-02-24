# Privacy Shield for macOS

A macOS menu bar application that uses your Mac's built-in webcam and Apple's Vision framework to detect "shoulder-surfing" and protect your screen in real-time.

## Features

| Feature | Description |
|---------|-------------|
| 🔍 **Face Detection** | Continuously monitors via the webcam using Apple's `Vision` framework |
| 👤 **Face Enrollment** | Register your face (and trusted faces) so only strangers trigger the blur |
| 🔒 **Instant Screen Blur** | Fullscreen `NSVisualEffectView` overlay across all displays |
| ⌨️ **Global Hotkey** | Press `⌘⇧L` anywhere to manually toggle the blur |
| 🔔 **Notifications** | macOS notification when an unrecognized face is detected |
| 🚀 **Launch at Login** | Optional auto-start when you log in |
| 🎯 **Frame Throttling** | Processes every 3rd frame to save CPU on laptops |
| 💤 **App Nap Disabled** | Stays active in the background without being throttled by macOS |
| 👥 **Multi-User Support** | Enroll multiple trusted faces (partner, coworker, etc.) |
| 📊 **Status Indicator** | Menu bar icon changes between `eye` (safe) and `eye.slash.fill` (shield active) |

## Requirements

- macOS 13 Ventura or newer (for Launch at Login via `SMAppService`)
- Mac with a built-in or external webcam
- Xcode 15+ (for building from source)

## How to Build and Run

1. **Clone the Repository**
   ```bash
   git clone https://github.com/GitGuru29/PrivacyShieldMac.git
   cd PrivacyShieldMac
   ```

2. **Open in Xcode**
   ```bash
   open PrivacyShield.xcodeproj
   ```

3. **Build & Run** — Press `⌘R`

4. **Grant Camera Access** — Click OK when macOS prompts you

## Usage

### First Launch
1. Look for the **eye icon** in your menu bar (top-right of screen).
2. Click it → **Enroll My Face** — look at the camera for ~2 seconds.
3. Done! The app now knows your face.

### Day-to-Day
- **You alone** → screen stays clear, icon shows `eye`
- **Stranger appears** → screen blurs instantly, icon shows `eye.slash.fill`, notification sent
- **Stranger leaves** → blur disappears automatically
- **Panic button** → press `⌘⇧L` from anywhere to toggle blur manually

### Adding Trusted Faces
Click **Add Trusted Face** in the menu → ask the person to look at the camera.

### Reset
Click **Reset All Enrollments** to wipe all saved face data.

## Architecture

```
PrivacyShieldApp.swift  →  SwiftUI entry point (menu bar only, no window)
AppDelegate.swift       →  Menu bar, global hotkey, notifications, launch-at-login
CameraManager.swift     →  AVCaptureSession → video frames
FaceDetector.swift      →  VNDetectFaceRectanglesRequest → face count + recognition
FaceRecognizer.swift    →  VNGenerateImageFeaturePrintRequest → enrollment + matching
ShieldManager.swift     →  NSWindow + NSVisualEffectView blur overlay
Toast.swift             →  Lightweight toast notifications
```
