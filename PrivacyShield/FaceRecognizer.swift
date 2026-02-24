import Vision
import AppKit
import CoreVideo

class FaceRecognizer {
    
    private var ownerPrints: [VNFeaturePrintObservation] = []
    private let maxEnrollmentSamples = 5
    private let matchThreshold: Float = 0.6  // Lower = stricter match
    
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PrivacyShield", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("owner_prints.dat")
    }
    
    var isEnrolled: Bool {
        return !ownerPrints.isEmpty
    }
    
    init() {
        loadPrints()
    }
    
    // MARK: - Enrollment
    
    /// Enroll the owner's face from a pixel buffer. Call this multiple times with different frames for robustness.
    /// Returns true if enrollment sample was captured successfully.
    func enrollFace(from pixelBuffer: CVPixelBuffer) -> Bool {
        guard let facePrint = generateFacePrint(from: pixelBuffer) else {
            print("Enrollment: No face found or feature print failed")
            return false
        }
        
        if ownerPrints.count < maxEnrollmentSamples {
            ownerPrints.append(facePrint)
            print("Enrollment: Captured sample \(ownerPrints.count)/\(maxEnrollmentSamples)")
        }
        
        if ownerPrints.count >= maxEnrollmentSamples {
            savePrints()
            print("Enrollment complete! \(ownerPrints.count) samples saved.")
            return true
        }
        
        return true
    }
    
    var enrollmentProgress: Int {
        return ownerPrints.count
    }
    
    var enrollmentTarget: Int {
        return maxEnrollmentSamples
    }
    
    func resetEnrollment() {
        ownerPrints.removeAll()
        try? FileManager.default.removeItem(at: storageURL)
        print("Enrollment reset")
    }
    
    // MARK: - Recognition
    
    /// Check if a face in the given pixel buffer (at the given normalized rect) matches the enrolled owner.
    func isOwner(pixelBuffer: CVPixelBuffer, faceRect: CGRect) -> Bool {
        guard isEnrolled else {
            // If not enrolled, treat everyone as owner (don't blur)
            return true
        }
        
        guard let facePrint = generateFacePrint(from: pixelBuffer, faceRect: faceRect) else {
            return false // Can't identify → treat as stranger
        }
        
        // Compare against all enrolled prints, use the best (smallest) distance
        var bestDistance: Float = Float.greatestFiniteMagnitude
        for ownerPrint in ownerPrints {
            var distance: Float = 0
            do {
                try facePrint.computeDistance(&distance, to: ownerPrint)
                if distance < bestDistance {
                    bestDistance = distance
                }
            } catch {
                print("Distance computation failed: \(error)")
            }
        }
        
        let isMatch = bestDistance < matchThreshold
        print("Face match distance: \(bestDistance) → \(isMatch ? "OWNER" : "STRANGER")")
        return isMatch
    }
    
    // MARK: - Feature Print Generation
    
    private func generateFacePrint(from pixelBuffer: CVPixelBuffer, faceRect: CGRect? = nil) -> VNFeaturePrintObservation? {
        // Step 1: Detect face if no rect provided
        let detectedRect: CGRect
        if let rect = faceRect {
            detectedRect = rect
        } else {
            let faceRequest = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            do {
                try handler.perform([faceRequest])
            } catch {
                print("Face detection for enrollment failed: \(error)")
                return nil
            }
            guard let face = (faceRequest.results as? [VNFaceObservation])?.first else {
                return nil
            }
            detectedRect = face.boundingBox
        }
        
        // Step 2: Crop face region from pixel buffer
        guard let faceImage = cropFace(from: pixelBuffer, rect: detectedRect) else {
            print("Failed to crop face")
            return nil
        }
        
        // Step 3: Generate feature print of the cropped face
        let featurePrintRequest = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: faceImage, options: [:])
        do {
            try handler.perform([featurePrintRequest])
        } catch {
            print("Feature print generation failed: \(error)")
            return nil
        }
        
        return featurePrintRequest.results?.first as? VNFeaturePrintObservation
    }
    
    private func cropFace(from pixelBuffer: CVPixelBuffer, rect: CGRect) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width = ciImage.extent.width
        let height = ciImage.extent.height
        
        // Vision returns normalized coords (0-1), convert to pixel coords
        // Add some padding around the face for better feature extraction
        let padding: CGFloat = 0.15
        let x = max(0, (rect.origin.x - padding) * width)
        let y = max(0, (rect.origin.y - padding) * height)
        let w = min(width - x, (rect.width + padding * 2) * width)
        let h = min(height - y, (rect.height + padding * 2) * height)
        
        let cropRect = CGRect(x: x, y: y, width: w, height: h)
        let croppedCI = ciImage.cropped(to: cropRect)
        
        let context = CIContext()
        return context.createCGImage(croppedCI, from: croppedCI.extent)
    }
    
    // MARK: - Persistence
    
    private func savePrints() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: ownerPrints, requiringSecureCoding: true)
            try data.write(to: storageURL)
            print("Saved \(ownerPrints.count) prints to disk")
        } catch {
            print("Failed to save prints: \(error)")
        }
    }
    
    private func loadPrints() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            if let prints = try NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: VNFeaturePrintObservation.self, from: data) {
                ownerPrints = prints
                print("Loaded \(ownerPrints.count) enrolled prints from disk")
            }
        } catch {
            print("Failed to load prints: \(error)")
        }
    }
}
