import AVFoundation
import AppKit

protocol CameraManagerDelegate: AnyObject {
    func didOutput(pixelBuffer: CVPixelBuffer)
}

class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession!
    private weak var delegate: CameraManagerDelegate?
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    
    init(delegate: CameraManagerDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func checkPermissionAndStart() {
        print("Camera auth status: \(AVCaptureDevice.authorizationStatus(for: .video))")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.setupAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("Camera permission result: \(granted)")
                if granted {
                    DispatchQueue.main.async {
                        self.setupAndStartSession()
                    }
                }
            }
        default:
            print("Camera permission denied")
        }
    }
    
    private func setupAndStartSession() {
        print("Setting up capture session…")
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .low // low res is sufficient for generic face detection and faster
        
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get default camera device. This Mac might not have a camera or permissions were blocked.")
            return
        }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("Failed to create camera input from device.")
            return
        }
        
        guard captureSession.canAddInput(videoDeviceInput) else {
            print("Failed to add camera input to session.")
            return
        }
        captureSession.addInput(videoDeviceInput)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            print("Added video data output")
        }
        
        // Add connection orientation if needed (usually front camera naturally upright but lets let Vision handle it)
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            if let running = self?.captureSession?.isRunning { print("Capture session started: \(running)") }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("Got frame")
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.didOutput(pixelBuffer: pixelBuffer)
    }
}
