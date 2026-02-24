import Vision
import CoreVideo
import Foundation

class FaceDetector: NSObject, CameraManagerDelegate {
    private let shieldManager: ShieldManager
    let faceRecognizer: FaceRecognizer
    private var consecutiveStranger = 0
    private let triggerThreshold = 3
    private var isProcessing = false
    
    /// When true, the next frames will be used for enrollment instead of recognition
    var isEnrolling = false
    var enrollmentCompletion: ((Bool) -> Void)?
    
    init(shieldManager: ShieldManager) {
        self.shieldManager = shieldManager
        self.faceRecognizer = FaceRecognizer()
        super.init()
    }
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        guard !isProcessing else { return }
        isProcessing = true
        
        // If we're in enrollment mode, capture a sample
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
        
        // Normal recognition mode
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        
        do {
            try requestHandler.perform([request])
            let faces = (request.results as? [VNFaceObservation]) ?? []
            let count = faces.count
            
            // Check if any face is a stranger
            var strangerDetected = false
            
            if count == 0 {
                // No faces at all → blur (user walked away)
                strangerDetected = true
            } else if !faceRecognizer.isEnrolled {
                // Not enrolled yet → don't blur (old behavior: only blur if >1 face)
                strangerDetected = count > 1
            } else {
                // Enrolled → check each face
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
                print("⚠️ Stranger or no-face detected (\(faceCount) faces) → BLUR")
                shieldManager.showShield()
            }
        } else {
            consecutiveStranger = 0
            shieldManager.hideShield()
        }
    }
    
    func startEnrollment(completion: @escaping (Bool) -> Void) {
        faceRecognizer.resetEnrollment()
        enrollmentCompletion = completion
        isEnrolling = true
        print("Enrollment started — look at the camera...")
    }
}
