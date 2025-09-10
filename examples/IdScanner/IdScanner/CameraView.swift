import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isProcessing = false

    let onImageCaptured: (UIImage, [String]) -> Void

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
                .onAppear {
                    print("📱 CameraPreviewView appeared")
                }
            
            OverlayView(
                faces: cameraManager.detectedFaces,
                rectangles: cameraManager.detectedRectangles,
                previewLayer: cameraManager.previewLayer
            )
            
            VStack {
                Spacer()
                
                Button(action: captureImage) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 70, height: 70)
                        )
                }
                .disabled(isProcessing)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            print("📱 CameraView appeared, starting session")
            cameraManager.startSession()
        }
        .onDisappear {
            print("📱 CameraView disappeared, stopping session")
            cameraManager.stopSession()
        }
    }
    
    private func captureImage() {
        print("🔥 CAPTURE: Starting image capture")
        isProcessing = true
        
        cameraManager.capturePhoto { capturedImage in
            DispatchQueue.main.async {
                guard let image = capturedImage else {
                    print("❌ CAPTURE: Failed to capture image")
                    self.isProcessing = false
                    return
                }
                
                print("✅ CAPTURE: Successfully captured image")
                print("📏 CAPTURE: Original image size: \(image.size)")
                print("🔍 CAPTURE: Detected rectangles count: \(self.cameraManager.detectedRectangles.count)")
                
                // Debug: Save original image to see what we captured
                self.debugSaveImage(image, name: "original_capture")
                
                // Use the detected rectangle for rectification
                let rectangle = self.cameraManager.detectedRectangles.first
                if let rect = rectangle {
                    print("📐 RECTIFY: Using detected rectangle for rectification")
                    print("📐 RECTIFY: Rectangle confidence: \(rect.confidence)")
                    print("📐 RECTIFY: Rectangle corners: TL(\(rect.topLeft)), TR(\(rect.topRight)), BR(\(rect.bottomRight)), BL(\(rect.bottomLeft))")
                } else {
                    print("⚠️ RECTIFY: No rectangle detected, using original image")
                }
                
                let rectified = ImageRectifier.rectify(image: image, rectangle: rectangle)
                print("🔧 RECTIFY: Rectified image size: \(rectified.size)")
                
                // Debug: Save rectified image to see if it's white
                self.debugSaveImage(rectified, name: "rectified_image")
                
                // Verify we have a valid rectified image
                guard rectified.size.width > 0 && rectified.size.height > 0 else {
                    print("❌ RECTIFY: ERROR - Rectified image has invalid size")
                    // Fallback to original image
                    let ocr = OCRService.extractText(from: image)
                    self.onImageCaptured(image, ocr)
                    self.isProcessing = false
                    return
                }
                
                // Check if rectified image is actually different from original
                if rectified.size == image.size && rectangle == nil {
                    print("ℹ️ RECTIFY: Using original image (no rectification needed)")
                } else {
                    print("✅ RECTIFY: Successfully rectified image")
                }
                
                // Process with OCR
                print("📝 OCR: Starting text extraction")
                let ocr = OCRService.extractText(from: rectified)
                print("📝 OCR: Extracted \(ocr.count) text elements: \(ocr)")
                
                // Call completion
                print("🎯 COMPLETION: Calling onImageCaptured with rectified image")
                self.onImageCaptured(rectified, ocr)
                self.isProcessing = false
            }
        }
    }
    
    // Debug helper to save images for inspection
    private func debugSaveImage(_ image: UIImage, name: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(name)_\(Date().timeIntervalSince1970).jpg")
        try? data.write(to: fileURL)
        print("💾 DEBUG: Saved \(name) to \(fileURL.path)")
    }
}

// MARK: - Preview
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView { image, ocr in
            print("Captured image with OCR: \(ocr)")
        }
    }
}
