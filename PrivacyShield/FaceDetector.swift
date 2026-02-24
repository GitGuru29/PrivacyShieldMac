import Vision
import CoreVideo
import Foundation

protocol FaceDetectorDelegate: AnyObject {
    func updateMenuIcon(safe: Bool)
    func sendStrangerNotification()
}

class FaceDetector: NSObject, CameraManagerDelegate {
    private let shieldManager: ShieldManager
    let faceRecognizer: FaceRecognizer
    private weak var delegate: FaceDetectorDelegate?
    
    // Anti-glitch: separate counters for entering and exiting blur state
    private var consecutiveStranger = 0
    private var consecutiveSafe = 0
    private let strangerThreshold = 3     // Frames before SHOWING shield
    private let safeThreshold = 8         // Frames before HIDING shield (higher = more stable)
    private var isShieldActive = false
    
    private var isProcessing = false
    private var frameCounter = 0
    private let frameSkip = 3
    private var hasNotifiedStranger = false
    
    /// Minimum face size (0.0–1.0 of frame width) to trigger detection.
    /// Faces smaller than this are too far away to read the screen.
    var minFaceSize: CGFloat {
        get {
            let val = CGFloat(UserDefaults.standard.float(forKey: "minFaceSize"))
            return val > 0 ? val : 0.25
        }
        set { UserDefaults.standard.set(Float(newValue), forKey: "minFaceSize") }
    }
    
    // Use a buffer zone: faces within 80% of the threshold are "borderline" and don't trigger changes
    private var faceBufferRatio: CGFloat = 0.8
    
    /// Enrollment mode
    var isEnrolling = false
    var enrollmentCompletion: ((Bool) -> Void)?
    
    /// Calibration mode
    var isCalibrating = false
    private var calibrationSamples: [CGFloat] = []
    private let calibrationSampleCount = 10
    var calibrationCompletion: ((Bool, CGFloat) -> Void)?
    
    init(shieldManager: ShieldManager, delegate: FaceDetectorDelegate) {
        self.shieldManager = shieldManager
        self.faceRecognizer = FaceRecognizer()
        self.delegate = delegate
        super.init()
    }
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        frameCounter += 1
        guard frameCounter % frameSkip == 0 else { return }
        guard !isProcessing else { return }
        isProcessing = true
        
        // Enrollment mode
        if isEnrolling {
            let _ = faceRecognizer.enrollFace(from: pixelBuffer)
            if faceRecognizer.enrollmentProgress >= faceRecognizer.enrollmentTarget {
                DispatchQueue.main.async { [weak self] in
                    self?.isEnrolling = false
                    self?.enrollmentCompletion?(true)
                    self?.enrollmentCompletion = nil
                }
            }
            isProcessing = false
            return
        }
        
        // Calibration mode
        if isCalibrating {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            let req = VNDetectFaceRectanglesRequest()
            do {
                try handler.perform([req])
                if let face = (req.results as? [VNFaceObservation])?.first {
                    calibrationSamples.append(face.boundingBox.width)
                    print("Calibration sample \(calibrationSamples.count)/\(calibrationSampleCount): face width = \(face.boundingBox.width)")
                    
                    if calibrationSamples.count >= calibrationSampleCount {
                        let avgSize = calibrationSamples.reduce(0, +) / CGFloat(calibrationSamples.count)
                        DispatchQueue.main.async { [weak self] in
                            self?.isCalibrating = false
                            self?.minFaceSize = avgSize
                            self?.calibrationCompletion?(true, avgSize)
                            self?.calibrationCompletion = nil
                        }
                    }
                }
            } catch {}
            isProcessing = false
            return
        }
        
        // Recognition mode
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        
        do {
            try requestHandler.perform([request])
            let faces = (request.results as? [VNFaceObservation]) ?? []
            let count = faces.count
            
            var strangerDetected = false
            
            // Filter faces by size with buffer zone to prevent glitching at the boundary
            let softThreshold = minFaceSize * faceBufferRatio  // Inner threshold (hysteresis)
            let nearbyFaces = faces.filter { $0.boundingBox.width >= softThreshold }
            let nearbyCount = nearbyFaces.count
            
            if count == 0 {
                // No faces at all → user walked away → blur
                strangerDetected = true
            } else if nearbyCount == 0 {
                // Faces exist but all far away → safe
                strangerDetected = false
            } else if !faceRecognizer.isEnrolled {
                // Not enrolled → only blur if multiple close faces
                strangerDetected = nearbyCount > 1
            } else {
                // Enrolled → check each nearby face against owner
                for face in nearbyFaces {
                    let isKnown = faceRecognizer.isOwner(pixelBuffer: pixelBuffer, faceRect: face.boundingBox)
                    if !isKnown {
                        strangerDetected = true
                        break
                    }
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.handleResult(strangerDetected: strangerDetected, faceCount: count)
                self?.isProcessing = false
            }
        } catch {
            print("Face detection failed: \(error)")
            isProcessing = false
        }
    }
    
    private func handleResult(strangerDetected: Bool, faceCount: Int) {
        if strangerDetected {
            consecutiveStranger += 1
            consecutiveSafe = 0  // Reset safe counter
            
            // Only SHOW shield after sustained stranger detection
            if !isShieldActive && consecutiveStranger >= strangerThreshold {
                isShieldActive = true
                shieldManager.showShield()
                delegate?.updateMenuIcon(safe: false)
                
                if !hasNotifiedStranger {
                    hasNotifiedStranger = true
                    delegate?.sendStrangerNotification()
                }
            }
        } else {
            consecutiveSafe += 1
            consecutiveStranger = 0  // Reset stranger counter
            
            // Only HIDE shield after sustained safe detection (prevents flickering)
            if isShieldActive && consecutiveSafe >= safeThreshold {
                isShieldActive = false
                hasNotifiedStranger = false
                shieldManager.hideShield()
                delegate?.updateMenuIcon(safe: true)
            } else if !isShieldActive {
                // Not active, just update icon
                delegate?.updateMenuIcon(safe: true)
            }
        }
    }
    
    func startEnrollment(userLabel: String, completion: @escaping (Bool) -> Void) {
        faceRecognizer.startNewEnrollment(label: userLabel)
        enrollmentCompletion = completion
        isEnrolling = true
        print("Enrollment started for '\(userLabel)' — look at the camera...")
    }
    
    func startCalibration(completion: @escaping (Bool, CGFloat) -> Void) {
        calibrationSamples.removeAll()
        calibrationCompletion = completion
        isCalibrating = true
        print("Calibration started — stand at your desired distance and look at the camera...")
    }
}
