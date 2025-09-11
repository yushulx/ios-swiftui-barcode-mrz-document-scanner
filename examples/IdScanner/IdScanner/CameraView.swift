import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isProcessing = false
    @State private var processingStep = ""
    @State private var processingProgress: Double = 0.0

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
            
            // Processing Animation Overlay
            if isProcessing {
                ProcessingOverlay(
                    step: processingStep,
                    progress: processingProgress
                )
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
        processingStep = "Capturing image..."
        processingProgress = 0.1
        
        cameraManager.capturePhoto { capturedImage in
            DispatchQueue.main.async {
                guard let image = capturedImage else {
                    self.isProcessing = false
                    return
                }
                
                // Update progress for image rectification
                self.processingStep = "Processing image..."
                self.processingProgress = 0.3
                
                // Use the detected rectangle for rectification
                let rectangle = self.cameraManager.detectedRectangles.first
                let rectified = ImageRectifier.rectify(image: image, rectangle: rectangle)
                
                // Verify we have a valid rectified image
                guard rectified.size.width > 0 && rectified.size.height > 0 else {
                    // Fallback to original image - process MRZ and OCR
                    self.processingStep = "Extracting text (OCR)..."
                    self.processingProgress = 0.5
                    
                    let ocr = OCRService.extractText(from: image)
                    
                    // Process MRZ on the captured image
                    self.processingStep = "Reading document (MRZ)..."
                    self.processingProgress = 0.8
                    
                    self.cameraManager.processMRZOnImage(image) { mrzResults in
                        DispatchQueue.main.async {
                            self.processingStep = "Complete!"
                            self.processingProgress = 1.0
                            
                            // Small delay to show completion
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.onImageCaptured(image, ocr, mrzResults)
                                self.isProcessing = false
                                self.processingProgress = 0.0
                            }
                        }
                    }
                    return
                }
                
                // Process with OCR
                self.processingStep = "Extracting text (OCR)..."
                self.processingProgress = 0.5
                
                let ocr = OCRService.extractText(from: rectified)
                
                // Process MRZ on the rectified (normalized) image - much better results!
                self.processingStep = "Reading document (MRZ)..."
                self.processingProgress = 0.8
                
                self.cameraManager.processMRZOnImage(rectified) { mrzResults in
                    DispatchQueue.main.async {
                        self.processingStep = "Complete!"
                        self.processingProgress = 1.0
                        
                        // Small delay to show completion
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.onImageCaptured(rectified, ocr, mrzResults)
                            self.isProcessing = false
                            self.processingProgress = 0.0
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Processing Overlay
struct ProcessingOverlay: View {
    let step: String
    let progress: Double
    
    @State private var spinnerRotation = 0.0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated spinner
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .rotationEffect(Angle(degrees: spinnerRotation))
                        .animation(
                            Animation.linear(duration: 1.0)
                                .repeatForever(autoreverses: false),
                            value: spinnerRotation
                        )
                }
                .onAppear {
                    spinnerRotation = 360
                }
                
                VStack(spacing: 12) {
                    // Processing step text
                    Text(step)
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Progress bar
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 4)
                            .frame(width: 200)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(height: 4)
                            .frame(width: 200 * progress)
                            .cornerRadius(2)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                    
                    // Progress percentage
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .shadow(radius: 10)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}

// MARK: - Preview
struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CameraView { image, ocr, mrzData in
                print("Captured image with OCR: \(ocr), MRZ: \(mrzData)")
            }
            .previewDisplayName("Camera View")
            
            ProcessingOverlay(
                step: "Reading document (MRZ)...",
                progress: 0.8
            )
            .previewDisplayName("Processing Overlay")
        }
    }
}
