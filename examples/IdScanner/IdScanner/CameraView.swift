import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isProcessing = false

    let onImageCaptured: (UIImage, [String], [String: String]) -> Void

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            OverlayView(
                faces: cameraManager.detectedFaces,
                rectangles: cameraManager.detectedRectangles,
                // Remove real-time MRZ contour display
                previewLayer: cameraManager.previewLayer,
                imageWidth: cameraManager.imageWidth,
                imageHeight: cameraManager.imageHeight
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
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.cleanup()
        }
    }
    
    private func captureImage() {
        isProcessing = true
        
        cameraManager.capturePhoto { capturedImage in
            DispatchQueue.main.async {
                guard let image = capturedImage else {
                    self.isProcessing = false
                    return
                }
                
                // Use the detected rectangle for rectification
                let rectangle = self.cameraManager.detectedRectangles.first
                let rectified = ImageRectifier.rectify(image: image, rectangle: rectangle)
                
                // Verify we have a valid rectified image
                guard rectified.size.width > 0 && rectified.size.height > 0 else {
                    // Fallback to original image - process MRZ and OCR
                    let ocr = OCRService.extractText(from: image)
                    
                    // Process MRZ on the captured image
                    self.cameraManager.processMRZOnImage(image) { mrzResults in
                        self.onImageCaptured(image, ocr, mrzResults)
                        self.isProcessing = false
                    }
                    return
                }
                
                // Process with OCR
                let ocr = OCRService.extractText(from: rectified)
                
                // Process MRZ on the rectified (normalized) image - much better results!
                self.cameraManager.processMRZOnImage(rectified) { mrzResults in
                    self.onImageCaptured(rectified, ocr, mrzResults)
                    self.isProcessing = false
                }
            }
        }
    }
}

// MARK: - Preview
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView { image, ocr, mrzData in
            print("Captured image with OCR: \(ocr), MRZ: \(mrzData)")
        }
    }
}
