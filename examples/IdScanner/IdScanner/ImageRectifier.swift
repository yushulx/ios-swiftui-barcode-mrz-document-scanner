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
        
        // Handle image orientation properly
        let orientedImage = image.normalizedImage()
        guard let orientedCGImage = orientedImage.cgImage else {
            print("Failed to get oriented CGImage, returning original")
            return image
        }
        
        let imageSize = CGSize(width: orientedCGImage.width, height: orientedCGImage.height)
        print("Processing image of size: \(imageSize)")
        
        // Convert normalized coordinates to image coordinates
        let topLeft = convertPointForOrientedImage(rectangle.topLeft, imageSize: imageSize)
        let topRight = convertPointForOrientedImage(rectangle.topRight, imageSize: imageSize)
        let bottomLeft = convertPointForOrientedImage(rectangle.bottomLeft, imageSize: imageSize)
        let bottomRight = convertPointForOrientedImage(rectangle.bottomRight, imageSize: imageSize)
        
        print("Rectangle corners:")
        print("  TopLeft: \(topLeft)")
        print("  TopRight: \(topRight)")
        print("  BottomLeft: \(bottomLeft)")
        print("  BottomRight: \(bottomRight)")
        
        // Create the perspective correction filter
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
            print("Failed to create perspective filter, returning original")
            return image
        }
        
        let ciImage = CIImage(cgImage: orientedCGImage)
        perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        guard let outputImage = perspectiveFilter.outputImage else {
            print("Failed to get output from perspective filter, returning original")
            return image
        }
        
        let context = CIContext()
        guard let rectifiedCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            print("Failed to create rectified CGImage, returning original")
            return image
        }
        
        let rectifiedImage = UIImage(cgImage: rectifiedCGImage, scale: image.scale, orientation: .up)
        print("Successfully rectified image to size: \(rectifiedImage.size)")
        return rectifiedImage
    }
    
    private static func convertPointForOrientedImage(_ normalizedPoint: CGPoint, imageSize: CGSize) -> CGPoint {
        // For properly oriented images, Vision coordinates map directly
        // (0,0) = top-left, (1,1) = bottom-right
        return CGPoint(
            x: normalizedPoint.x * imageSize.width,
            y: normalizedPoint.y * imageSize.height
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

// Extension to normalize image orientation
extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
