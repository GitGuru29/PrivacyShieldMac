# Privacy Shield for macOS

Privacy Shield is a macOS background application that uses your Mac's built-in webcam and Apple's Vision framework to dynamically detect "shoulder-surfing" and protect your screen. 

If the system detects an unrecognized face looking over your shoulder (e.g., when more than 1 face is in the camera frame), it instantly blurs your active windows to protect your privacy.

## Features
- **Real-time Face Detection**: Uses Apple's native `Vision` framework for efficient, secure, and accurate face counting.
- **Hardware Agnostic**: Uses `AVFoundation` to acquire your Mac's default video capturing device. 
- **System-Wide Blur Overlay**: Projects a frameless `NSVisualEffectView` HUD window across all connected displays that obscures content without losing context.
- **Native SwiftUI & AppKit Architecture**: Runs lightly in the background with a minimalist menu bar app icon.

## Requirements
- macOS 10.15 Catalina or newer
- Mac Device with a built-in or externally connected Web Camera
- Xcode (for building from source)

## How to Build and Run
Because the application communicates directly with the macOS Camera API, it requires system-level permissions to run. 

1. **Clone the Repository**
   ```bash
   git clone https://github.com/GitGuru29/PrivacyShieldMac.git
   cd PrivacyShieldMac
   ```
2. **Open the Xcode Project**
   Open the `PrivacyShield.xcodeproj` file in Xcode.
   
3. **Check Permissions (If creating a new project)**
   Ensure your `Info.plist` or Xcode Build Target has the `NSCameraUsageDescription` added, or else the app will crash on launch:
   > "Privacy Shield needs camera access to detect faces and protect your screen from shoulder surfers."

4. **Build and Run (⌘R)**
   Click the Play button in Xcode. 

5. **Grant Camera Access**
   macOS will spawn a privacy dialogue asking for permission to use the camera. Click **OK**.

## How to Test
1. Make sure you are the only one sitting in front of the camera (1 face). The screen will appear normal.
2. Have a second person enter the frame next to you, or hold up a clear photo of another person's face (2 faces).
3. The screen will immediately blur across all monitors.
4. Once the second face leaves the frame, the blur will disappear.

## Quitting the App
To stop the background process and camera feed, look for the crossed-out eye icon (`eye.slash`) in your top-right macOS Menu Bar, click it, and select **Quit Privacy Shield**.
