import UIKit
import Vision
import CoreImage

class ImageRectifier {
    static func rectify(image: UIImage, rectangle: VNRectangleObservation?) -> UIImage {
        // If no rectangle detected, return original image
        guard let rectangle = rectangle else {
            print("No rectangle provided, returning original image")
            return image
        }
        
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage, returning original")
            return image
        }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        print("Processing image of size: \(imageSize)")
        
        // Convert normalized coordinates to image coordinates
        let topLeft = convertPoint(rectangle.topLeft, imageSize: imageSize)
        let topRight = convertPoint(rectangle.topRight, imageSize: imageSize)
        let bottomRight = convertPoint(rectangle.bottomRight, imageSize: imageSize)
        let bottomLeft = convertPoint(rectangle.bottomLeft, imageSize: imageSize)
        
        print("Rectangle corners:")
        print("  TopLeft: \(topLeft)")
        print("  TopRight: \(topRight)")
        print("  BottomRight: \(bottomRight)")
        print("  BottomLeft: \(bottomLeft)")
        
        // Create the perspective correction filter
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
            print("Failed to create perspective filter, returning original")
            return image
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        
        guard let outputImage = perspectiveFilter.outputImage else {
            print("Failed to get output from perspective filter, returning original")
            return image
        }
        
        let context = CIContext()
        guard let rectifiedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            print("Failed to create rectified CGImage, returning original")
            return image
        }
        
        let rectifiedImage = UIImage(cgImage: rectifiedCGImage)
        print("Successfully rectified image to size: \(rectifiedImage.size)")
        return rectifiedImage
    }
    
    private static func convertPoint(_ normalizedPoint: CGPoint, imageSize: CGSize) -> CGPoint {
        // Convert normalized Vision coordinates to actual image pixel coordinates
        // Vision uses normalized coordinates (0-1) with origin at bottom-left
        // Image coordinates use actual pixels with origin at top-left
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
