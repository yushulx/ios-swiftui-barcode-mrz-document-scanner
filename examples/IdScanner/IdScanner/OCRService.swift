import UIKit
import Vision

class OCRService {
    static func extractText(from image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        
        var extractedTexts: [String] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let textRecognitionRequest = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    extractedTexts.append(text)
                }
            }
        }
        
        // Configure text recognition for better accuracy
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
        
        // Set supported languages (you can modify this based on your needs)
        if #available(iOS 16.0, *) {
            textRecognitionRequest.automaticallyDetectsLanguage = true
        } else {
            textRecognitionRequest.recognitionLanguages = ["en-US"]
        }
        
        do {
            try requestHandler.perform([textRecognitionRequest])
            semaphore.wait()
        } catch {
            print("Failed to perform text recognition: \(error)")
        }
        
        return extractedTexts
    }
    
    static func extractTextWithBoundingBoxes(from image: UIImage) -> [(text: String, boundingBox: CGRect)] {
        guard let cgImage = image.cgImage else { return [] }
        
        var extractedData: [(text: String, boundingBox: CGRect)] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        let textRecognitionRequest = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            
            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !text.isEmpty {
                    // Convert normalized coordinates to image coordinates
                    let boundingBox = convertVisionBoundingBox(observation.boundingBox, imageSize: imageSize)
                    extractedData.append((text: text, boundingBox: boundingBox))
                }
            }
        }
        
        textRecognitionRequest.recognitionLevel = .accurate
        textRecognitionRequest.usesLanguageCorrection = true
        
        if #available(iOS 16.0, *) {
            textRecognitionRequest.automaticallyDetectsLanguage = true
        } else {
            textRecognitionRequest.recognitionLanguages = ["en-US"]
        }
        
        do {
            try requestHandler.perform([textRecognitionRequest])
            semaphore.wait()
        } catch {
            print("Failed to perform text recognition: \(error)")
        }
        
        return extractedData
    }
    
    private static func convertVisionBoundingBox(_ visionBox: CGRect, imageSize: CGSize) -> CGRect {
        let x = visionBox.origin.x * imageSize.width
        let y = (1 - visionBox.origin.y - visionBox.height) * imageSize.height
        let width = visionBox.width * imageSize.width
        let height = visionBox.height * imageSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
