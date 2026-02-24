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
    private var consecutiveStranger = 0
    private let triggerThreshold = 3
    private var isProcessing = false
    private var frameCounter = 0
    private let frameSkip = 3  // Only process every Nth frame for performance
    private var hasNotifiedStranger = false
    
    /// When true, the next frames will be used for enrollment instead of recognition
    var isEnrolling = false
    var enrollmentCompletion: ((Bool) -> Void)?
    
    init(shieldManager: ShieldManager, delegate: FaceDetectorDelegate) {
        self.shieldManager = shieldManager
        self.faceRecognizer = FaceRecognizer()
        self.delegate = delegate
        super.init()
    }
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        // Frame throttling — skip frames for performance
        frameCounter += 1
        guard frameCounter % frameSkip == 0 else { return }
        
        guard !isProcessing else { return }
        isProcessing = true
        
        // Enrollment mode
        if isEnrolling {
            let success = faceRecognizer.enrollFace(from: pixelBuffer)
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
        
        // Recognition mode
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        
        do {
            try requestHandler.perform([request])
            let faces = (request.results as? [VNFaceObservation]) ?? []
            let count = faces.count
            
            var strangerDetected = false
            
            if count == 0 {
                strangerDetected = true
            } else if !faceRecognizer.isEnrolled {
                strangerDetected = count > 1
            } else {
                for face in faces {
                    if !faceRecognizer.isOwner(pixelBuffer: pixelBuffer, faceRect: face.boundingBox) {
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
            if consecutiveStranger >= triggerThreshold {
                shieldManager.showShield()
                delegate?.updateMenuIcon(safe: false)
                
                // Send notification only once per stranger event
                if !hasNotifiedStranger {
                    hasNotifiedStranger = true
                    delegate?.sendStrangerNotification()
                }
            }
        } else {
            consecutiveStranger = 0
            hasNotifiedStranger = false
            shieldManager.hideShield()
            delegate?.updateMenuIcon(safe: true)
        }
    }
    
    func startEnrollment(userLabel: String, completion: @escaping (Bool) -> Void) {
        faceRecognizer.startNewEnrollment(label: userLabel)
        enrollmentCompletion = completion
        isEnrolling = true
        print("Enrollment started for '\(userLabel)' — look at the camera...")
    }
}
