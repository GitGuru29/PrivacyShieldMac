import AVFoundation
import AppKit

protocol CameraManagerDelegate: AnyObject {
    func didOutput(pixelBuffer: CVPixelBuffer)
}

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession?
    private weak var delegate: CameraManagerDelegate?
    private let videoDataOutputQueue = DispatchQueue(label: "com.privacyshield.videoqueue", qos: .userInitiated)
    
    init(delegate: CameraManagerDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func checkPermissionAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("Camera auth status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            setupAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                print("Camera permission result: \(granted)")
                if granted {
                    DispatchQueue.main.async {
                        self?.setupAndStartSession()
                    }
                } else {
                    print("User denied camera access")
                }
            }
        case .denied, .restricted:
            print("Camera permission denied or restricted. Please enable in System Settings > Privacy & Security > Camera")
        @unknown default:
            print("Unknown camera auth status")
        }
    }
    
    private func setupAndStartSession() {
        print("Setting up capture session…")
        
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .medium
        
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("ERROR: No camera device found")
            return
        }
        print("Found camera: \(videoDevice.localizedName)")
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            guard session.canAddInput(videoDeviceInput) else {
                print("ERROR: Cannot add camera input")
                return
            }
            session.addInput(videoDeviceInput)
        } catch {
            print("ERROR: Failed to create camera input: \(error)")
            return
        }
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        
        guard session.canAddOutput(videoDataOutput) else {
            print("ERROR: Cannot add video output")
            return
        }
        session.addOutput(videoDataOutput)
        print("Video output added successfully")
        
        session.commitConfiguration()
        self.captureSession = session
        
        // Start on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            let running = self?.captureSession?.isRunning ?? false
            print("Capture session running: \(running)")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.didOutput(pixelBuffer: pixelBuffer)
    }
}
