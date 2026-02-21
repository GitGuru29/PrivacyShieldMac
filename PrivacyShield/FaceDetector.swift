import Vision
import CoreVideo

class FaceDetector: CameraManagerDelegate {
    private let shieldManager: ShieldManager
    private var sequenceHandler = VNSequenceRequestHandler()
    private var consecutiveMultipleFaces = 0
    private let triggerThreshold = 2 // Require multiple frames to avoid flicker
    
    init(shieldManager: ShieldManager) {
        self.shieldManager = shieldManager
    }
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            if let results = request.results as? [VNFaceObservation] {
                DispatchQueue.main.async {
                    self.handleFaceDetection(facesCount: results.count)
                }
            }
        }
        
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            print("Face detection failed: \(error)")
        }
    }
    
    private func handleFaceDetection(facesCount: Int) {
        if facesCount > 1 {
            consecutiveMultipleFaces += 1
            if consecutiveMultipleFaces >= triggerThreshold {
                shieldManager.showShield()
            }
        } else {
            consecutiveMultipleFaces = 0
            shieldManager.hideShield()
        }
    }
}
