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
            
            // Debug overlay with frame info
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Frame Debug")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        
                        Text("Size: \(Int(cameraManager.currentFrameSize.width))x\(Int(cameraManager.currentFrameSize.height))")
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        
                        Text(cameraManager.frameOrientation)
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                        
                        if let thumbnail = cameraManager.currentFrameThumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .border(Color.red, width: 2)
                                .overlay(
                                    Text("Raw Frame")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                        .background(Color.white.opacity(0.8)),
                                    alignment: .bottom
                                )
                        }
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding()
            
            // Overlays for detected features
            OverlayView(
                faces: cameraManager.detectedFaces,
                rectangles: cameraManager.detectedRectangles
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Capture button
                Button(action: captureImage) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 70, height: 70)
                        
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        }
                    }
                }
                .disabled(isProcessing)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private func captureImage() {
        isProcessing = true
        print("Capture button pressed")
        
        cameraManager.capturePhoto { capturedImage in
            print("Photo captured: \(capturedImage != nil)")
            guard let image = capturedImage else {
                print("Failed to capture image")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            print("Processing image...")
            // Process the captured image
            processImage(image) { processedImage, ocrResults in
                print("Image processed, OCR results: \(ocrResults.count) items")
                DispatchQueue.main.async {
                    self.onImageCaptured(processedImage, ocrResults)
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage, completion: @escaping (UIImage, [String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            print("Processing image - size: \(image.size)")
            
            // Try to rectify the image based on detected rectangles
            let rectifiedImage = rectifyImage(image)
            print("Rectified image - size: \(rectifiedImage.size)")
            
            // Perform OCR on the rectified image
            let ocrResults = performOCR(on: rectifiedImage)
            print("OCR results: \(ocrResults)")
            
            completion(rectifiedImage, ocrResults)
        }
    }
    
    private func rectifyImage(_ image: UIImage) -> UIImage {
        // Find the best rectangle from current detections
        guard let bestRectangle = cameraManager.detectedRectangles.first else {
            print("No rectangles detected for rectification, using original image")
            return image // Return original if no rectangles detected
        }
        
        print("Rectifying image with rectangle confidence: \(bestRectangle.confidence)")
        print("Rectangle bounds: \(bestRectangle.boundingBox)")
        print("Rectangle corners - TL: \(bestRectangle.topLeft), TR: \(bestRectangle.topRight), BR: \(bestRectangle.bottomRight), BL: \(bestRectangle.bottomLeft)")
        
        let rectified = ImageRectifier.rectify(image: image, rectangle: bestRectangle)
        return rectified ?? image
    }
    
    private func performOCR(on image: UIImage) -> [String] {
        return OCRService.extractText(from: image)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove existing preview layer
        uiView.layer.sublayers?.removeAll()
        
        // Add preview layer if available
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            uiView.layer.addSublayer(previewLayer)
        }
    }
}

struct OverlayView: View {
    let faces: [VNFaceObservation]
    let rectangles: [VNRectangleObservation]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Debug rectangles - screen corners
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 50, height: 50)
                    .position(x: 25, y: 25) // Top left corner
                
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 50, height: 50)
                    .position(x: geometry.size.width - 25, y: geometry.size.height - 25) // Bottom right corner
                
                // Screen size info
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Screen Debug")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                            
                            Text("Size: \(Int(geometry.size.width))x\(Int(geometry.size.height))")
                                .font(.caption)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                            
                            Text("Red: Screen TL")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                            
                            Text("Yellow: Screen BR")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
                
                // Debug rectangles - Vision coordinate test points
                // Vision (0,0) - bottom left in Vision space
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: 30, height: 30)
                    .position(x: convertVisionPoint(CGPoint(x: 0, y: 0), to: geometry.size).x + 15,
                             y: convertVisionPoint(CGPoint(x: 0, y: 0), to: geometry.size).y + 15)
                
                // Vision (1,1) - top right in Vision space
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 30, height: 30)
                    .position(x: convertVisionPoint(CGPoint(x: 1, y: 1), to: geometry.size).x + 15,
                             y: convertVisionPoint(CGPoint(x: 1, y: 1), to: geometry.size).y + 15)
                
                // Vision (0,1) - top left in Vision space
                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: 30, height: 30)
                    .position(x: convertVisionPoint(CGPoint(x: 0, y: 1), to: geometry.size).x + 15,
                             y: convertVisionPoint(CGPoint(x: 0, y: 1), to: geometry.size).y + 15)
                
                // Vision (1,0) - bottom right in Vision space
                Rectangle()
                    .fill(Color.brown)
                    .frame(width: 30, height: 30)
                    .position(x: convertVisionPoint(CGPoint(x: 1, y: 0), to: geometry.size).x + 15,
                             y: convertVisionPoint(CGPoint(x: 1, y: 0), to: geometry.size).y + 15)
                
                // Vision coordinate legend
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Vision Coords:")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                            
                            HStack {
                                Circle().fill(Color.purple).frame(width: 10, height: 10)
                                Text("(0,0) V-BL")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.7))
                            }
                            
                            HStack {
                                Circle().fill(Color.orange).frame(width: 10, height: 10)
                                Text("(1,1) V-TR")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.7))
                            }
                            
                            HStack {
                                Circle().fill(Color.cyan).frame(width: 10, height: 10)
                                Text("(0,1) V-TL")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.7))
                            }
                            
                            HStack {
                                Circle().fill(Color.brown).frame(width: 10, height: 10)
                                Text("(1,0) V-BR")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.7))
                            }
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 150) // Below the frame debug info
                
                // Face detection overlays
                ForEach(Array(faces.enumerated()), id: \.offset) { index, face in
                    let rect = convertVisionRect(face.boundingBox, to: geometry.size)
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .overlay(
                            VStack(spacing: 2) {
                                Text("Face \(index)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(4)
                                
                                Text("Vision: (\(String(format: "%.2f", face.boundingBox.origin.x)), \(String(format: "%.2f", face.boundingBox.origin.y)))")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(3)
                                
                                Text("Size: \(String(format: "%.2f", face.boundingBox.width))×\(String(format: "%.2f", face.boundingBox.height))")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(3)
                                
                                Text("Screen: (\(Int(rect.origin.x)), \(Int(rect.origin.y)))")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(3)
                                
                                Text("Size: \(Int(rect.width))×\(Int(rect.height))")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .background(Color.blue.opacity(0.8))
                                    .cornerRadius(3)
                            }
                            .position(x: rect.midX, y: rect.minY - 50)
                        )
                }
                
                // Rectangle detection overlays
                ForEach(Array(rectangles.enumerated()), id: \.offset) { index, rectangle in
                    let path = convertVisionRectangleToPath(rectangle, to: geometry.size)
                    let boundingBox = rectangle.boundingBox
                    
                    // Draw the rectangle path
                    path
                        .stroke(Color.blue, lineWidth: 4)
                    
                    // Add coordinate debugging info
                    VStack(spacing: 2) {
                        Text("Document \(index)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(4)
                        
                        Text("Vision BBox: (\(String(format: "%.2f", boundingBox.origin.x)), \(String(format: "%.2f", boundingBox.origin.y)))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(3)
                        
                        let aspectRatio = boundingBox.width / boundingBox.height
                        let orientation = aspectRatio > 1.0 ? "Landscape" : "Portrait"
                        Text("Size: \(String(format: "%.2f", boundingBox.width))×\(String(format: "%.2f", boundingBox.height)) (\(orientation))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(3)
                        
                        Text("Aspect: \(String(format: "%.2f", aspectRatio))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(3)
                        
                        Text("Confidence: \(String(format: "%.2f", rectangle.confidence))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(3)
                        
                        Text("Corners:")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .background(Color.purple.opacity(0.8))
                            .cornerRadius(3)
                        
                        Text("TL: (\(String(format: "%.2f", rectangle.topLeft.x)), \(String(format: "%.2f", rectangle.topLeft.y)))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.purple.opacity(0.6))
                            .cornerRadius(3)
                        
                        Text("TR: (\(String(format: "%.2f", rectangle.topRight.x)), \(String(format: "%.2f", rectangle.topRight.y)))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.purple.opacity(0.6))
                            .cornerRadius(3)
                        
                        Text("BR: (\(String(format: "%.2f", rectangle.bottomRight.x)), \(String(format: "%.2f", rectangle.bottomRight.y)))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.purple.opacity(0.6))
                            .cornerRadius(3)
                        
                        Text("BL: (\(String(format: "%.2f", rectangle.bottomLeft.x)), \(String(format: "%.2f", rectangle.bottomLeft.y)))")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .background(Color.purple.opacity(0.6))
                            .cornerRadius(3)
                    }
                    .position(
                        x: convertVisionPoint(CGPoint(x: boundingBox.midX, y: boundingBox.maxY), to: geometry.size).x,
                        y: convertVisionPoint(CGPoint(x: boundingBox.midX, y: boundingBox.maxY), to: geometry.size).y - 60
                    )
                    
                    // Add corner dots to visualize the exact corner positions
                    Group {
                        let topLeft = convertVisionPoint(rectangle.topLeft, to: geometry.size)
                        let topRight = convertVisionPoint(rectangle.topRight, to: geometry.size)
                        let bottomRight = convertVisionPoint(rectangle.bottomRight, to: geometry.size)
                        let bottomLeft = convertVisionPoint(rectangle.bottomLeft, to: geometry.size)
                        
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .position(x: topLeft.x, y: topLeft.y)
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .position(x: topRight.x, y: topRight.y)
                        
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 8, height: 8)
                            .position(x: bottomRight.x, y: bottomRight.y)
                        
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .position(x: bottomLeft.x, y: bottomLeft.y)
                    }
                }
            }
        }
    }
    
    private func convertVisionPoint(_ point: CGPoint, to size: CGSize) -> CGPoint {
        // Vision processes with .right orientation (90° clockwise from sensor)
        // Screen is in portrait mode (width < height)
        // Camera sensor frame is landscape (width > height)
        
        // For .right orientation:
        // Vision X (0->1) maps to Screen Y (bottom->top) 
        // Vision Y (0->1) maps to Screen X (left->right)
        // Note: Vision Y is flipped due to front camera mirroring
        
        return CGPoint(
            x: (1 - point.y) * size.width,  // Flip Y to X due to front camera
            y: point.x * size.height        // X to Y mapping
        )
    }
    
    private func convertVisionRect(_ visionRect: CGRect, to size: CGSize) -> CGRect {
        // Convert Vision rectangle coordinates to screen coordinates
        // Vision uses .right orientation, screen is portrait
        
        let screenX = (1 - visionRect.origin.y - visionRect.height) * size.width
        let screenY = visionRect.origin.x * size.height
        let screenWidth = visionRect.height * size.width
        let screenHeight = visionRect.width * size.height
        
        return CGRect(
            x: screenX,
            y: screenY,
            width: screenWidth,
            height: screenHeight
        )
    }
    
    private func convertVisionRectangleToPath(_ rectangle: VNRectangleObservation, to size: CGSize) -> Path {
        // Convert each corner point from Vision coordinates to screen coordinates
        func convertPoint(_ point: CGPoint) -> CGPoint {
            // For .right orientation: Vision X->Screen Y, Vision Y->Screen X (flipped)
            return CGPoint(
                x: (1 - point.y) * size.width,  // Flip Y to X
                y: point.x * size.height        // X to Y
            )
        }
        
        let topLeft = convertPoint(rectangle.topLeft)
        let topRight = convertPoint(rectangle.topRight)
        let bottomRight = convertPoint(rectangle.bottomRight)
        let bottomLeft = convertPoint(rectangle.bottomLeft)
        
        var path = Path()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()
        
        return path
    }
}
