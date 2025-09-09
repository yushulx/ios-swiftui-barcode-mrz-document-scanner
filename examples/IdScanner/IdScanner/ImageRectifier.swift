import UIKit
import Vision
import CoreImage

class ImageRectifier {
    static func rectify(image: UIImage, rectangle: VNRectangleObservation) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Convert normalized coordinates to image coordinates
        let topLeft = convertPoint(rectangle.topLeft, imageSize: imageSize)
        let topRight = convertPoint(rectangle.topRight, imageSize: imageSize)
        let bottomRight = convertPoint(rectangle.bottomRight, imageSize: imageSize)
        let bottomLeft = convertPoint(rectangle.bottomLeft, imageSize: imageSize)
        
        // Create the perspective correction filter
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        
        guard let outputImage = perspectiveFilter.outputImage else { return nil }
        
        let context = CIContext()
        guard let rectifiedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: rectifiedCGImage)
    }
    
    private static func convertPoint(_ normalizedPoint: CGPoint, imageSize: CGSize) -> CGPoint {
        // For .right orientation with rightMirrored preview transformation to image coordinates
        // Vision X maps to Image Y, Vision Y maps to (1 - Image X) due to mirror
        return CGPoint(
            x: (1 - normalizedPoint.y) * imageSize.width,
            y: normalizedPoint.x * imageSize.height
        )
        return CGPoint(
            x: normalizedPoint.x * imageSize.width,
            y: (1 - normalizedPoint.y) * imageSize.height
        )
    }
    
    static func enhanceImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // Apply filters to enhance the image for better OCR
        var outputImage = ciImage
        
        // Enhance contrast
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(outputImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.2, forKey: kCIInputContrastKey)
            if let result = contrastFilter.outputImage {
                outputImage = result
            }
        }
        
        // Sharpen the image
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(outputImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)
            if let result = sharpenFilter.outputImage {
                outputImage = result
            }
        }
        
        guard let finalCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: finalCGImage)
    }
}
