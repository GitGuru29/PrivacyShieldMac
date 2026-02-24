import Vision
import CoreVideo
import Foundation

class FaceDetector: NSObject, CameraManagerDelegate {
    private let shieldManager: ShieldManager
    private var consecutiveMultipleFaces = 0
    private let triggerThreshold = 3
    private var isProcessing = false
    
    init(shieldManager: ShieldManager) {
        self.shieldManager = shieldManager
        super.init()
    }
    
    func didOutput(pixelBuffer: CVPixelBuffer) {
        // Skip frame if we're still processing the previous one
        guard !isProcessing else { return }
        isProcessing = true
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        
        // Perform synchronously on the camera queue (we're already on a background queue)
        do {
            try requestHandler.perform([request])
            let count = (request.results as? [VNFaceObservation])?.count ?? 0
            
            DispatchQueue.main.async { [weak self] in
                self?.handleFaceDetection(facesCount: count)
                self?.isProcessing = false
            }
        } catch {
            print("Face detection failed: \(error)")
            isProcessing = false
        }
    }
    
    private func handleFaceDetection(facesCount: Int) {
        print("Faces detected: \(facesCount)")
        
        if facesCount != 1 {
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
