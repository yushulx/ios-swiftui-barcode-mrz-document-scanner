

### 3. Configure Permissions

Add camera permission to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for document scanning and face detection.</string>
```

## Core Architecture Overview

Our document scanner follows a sophisticated MVVM (Model-View-ViewModel) architecture designed for performance, maintainability, and scalability. The architecture separates concerns cleanly while ensuring smooth real-time processing and memory efficiency.

### High-Level Architecture

```
                           📱 iOS Document Scanner Architecture
                                        
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  UI Layer (SwiftUI)                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │   ContentView   │    │   CameraView    │    │   ResultView    │            │
│  │ (Navigation)    │◄──►│ (Camera UI)     │◄──►│ (Results UI)    │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
│            │                        │                        │                 │
└────────────┼────────────────────────┼────────────────────────┼─────────────────┘
             │                        │                        │
             ▼                        ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Business Logic Layer                               │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │PermissionsManager│   │  CameraManager  │    │   OCRService    │            │
│  │ (Auth Logic)    │    │ (Camera+Vision) │◄──►│ (Text Extract)  │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
│                                  │                        │                    │
│                                  ▼                        ▼                    │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │ ImageRectifier  │    │   OverlayView   │    │ ParsedItemModel │            │
│  │ (Perspective)   │    │ (Visual Feed)   │    │ (MRZ Data)      │            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
└─────────────────────────────────────────────────────────────────────────────────┘
             │                        │                        │
             ▼                        ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               System Layer                                      │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐            │
│  │  AVFoundation   │    │ Vision Framework│    │ Dynamsoft SDK   │            │
│  │ (Camera APIs)   │    │ (Face+Document) │    │ (MRZ Processing)│            │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘            │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

#### 🖥 **UI Layer (SwiftUI Views)**
- **ContentView**: Main navigation controller with permission handling
- **CameraView**: Real-time camera interface with capture controls
- **CameraPreviewView**: AVFoundation camera preview integration
- **OverlayView**: Visual feedback for detected faces and documents
- **ResultView**: Results display with OCR text and MRZ data
- **ProcessingOverlay**: Animated processing feedback

#### 🔧 **Business Logic Layer (ViewModels & Services)**
- **CameraManager**: 
  - Camera session management and configuration
  - Real-time face and document detection
  - Image capture and quality optimization
  - Memory-efficient processing coordination
  
- **PermissionsManager**: 
  - Camera authorization handling
  - Permission state management
  - Settings navigation

- **OCRService**: 
  - Vision framework text recognition
  - Accuracy optimization
  - Async text extraction

- **ImageRectifier**: 
  - Perspective correction algorithms
  - Document boundary processing
  - Core Image transformations

- **ParsedItemModel**: 
  - MRZ data validation and parsing
  - Structured document information
  - Commercial SDK integration

#### ⚙️ **System Layer (iOS Frameworks)**
- **AVFoundation**: Camera capture, session management, quality presets
- **Vision Framework**: Face detection, document detection, OCR processing
- **Dynamsoft SDK**: Commercial MRZ processing and validation

### Data Flow Architecture

```
📷 Camera Input → Vision Processing → UI Updates → User Interaction → Results
     │               │                  │              │             │
     ▼               ▼                  ▼              ▼             ▼
┌──────────┐   ┌──────────┐      ┌──────────┐   ┌──────────┐  ┌──────────┐
│ AVSession│──▶│ Detection│─────▶│ Overlays │◄─▶│ Capture  │─▶│ Process  │
│ (Camera) │   │(Vision)  │      │(SwiftUI) │   │ Button   │  │ Results  │
└──────────┘   └──────────┘      └──────────┘   └──────────┘  └──────────┘
     │               │                  │              │             │
     ▼               ▼                  ▼              ▼             ▼
Real-time      Face+Document     Visual Feedback    Image       OCR+MRZ
Streaming      Recognition       Green Outlines     Capture     Extraction
```

### Memory Management Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Memory Optimization Layers                   │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │ Real-time       │    │ On-demand       │                   │
│  │ Processing      │    │ Processing      │                   │
│  │ - Face detect   │    │ - MRZ scanning  │                   │
│  │ - Doc detect    │    │ - OCR extract   │                   │
│  │ - UI updates    │    │ - Image rectify │                   │
│  │ (Throttled 15fps)│   │ (User triggered)│                   │
│  └─────────────────┘    └─────────────────┘                   │
│           │                        │                          │
│           ▼                        ▼                          │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │              Memory Management                          │  │
│  │  • autoreleasepool for image processing               │  │
│  │  • Background queues for heavy operations             │  │
│  │  • Immediate cleanup of sample buffers                │  │
│  │  • Proper deinit methods                              │  │
│  │  • Throttled UI updates                               │  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Performance Characteristics

#### ⚡ **Real-time Components** (60fps target)
- Camera preview rendering
- Face detection overlays
- Document boundary highlighting
- UI animations and transitions

#### 🎯 **Optimized Components** (15fps target)
- Vision framework detection
- Overlay coordinate calculations
- Detection result publishing

#### 🔄 **On-demand Components** (User-triggered)
- Image capture and rectification
- OCR text extraction
- MRZ data processing
- Results navigation

This architecture ensures smooth performance while providing comprehensive document scanning capabilities, balancing real-time feedback with memory efficiency.

## Step 1: Permissions Management

First, let's create a permissions manager to handle camera access:

```swift
import AVFoundation
import SwiftUI

@MainActor
class PermissionsManager: ObservableObject {
    @Published var isCameraAuthorized = false
    @Published var isRequestingPermission = false
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            requestCameraPermission()
        case .denied, .restricted:
            isCameraAuthorized = false
        @unknown default:
            isCameraAuthorized = false
        }
    }
    
    private func requestCameraPermission() {
        isRequestingPermission = true
        
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isRequestingPermission = false
                self?.isCameraAuthorized = granted
            }
        }
    }
}
```

### Permission UI Views

Create user-friendly permission views:

```swift
struct PermissionsView: View {
    let permissionsManager: PermissionsManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This app needs camera access to scan documents and detect faces.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if permissionsManager.isRequestingPermission {
                    ProgressView("Requesting permission...")
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        Button("Enable Camera") {
                            permissionsManager.checkPermissions()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(permissionsManager.isRequestingPermission)
                        
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
        }
    }
}
```

## Step 2: Advanced Camera Manager

Now, let's create the heart of our app - a sophisticated camera manager:

```swift
import AVFoundation
import UIKit
import Vision
import DynamsoftMRZScannerBundle

final class CameraManager: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var detectedFaces: [VNFaceObservation] = []
    @Published var detectedRectangles: [VNRectangleObservation] = []
    @Published var isSessionRunning = false
    
    // Image dimensions for coordinate conversion
    @Published var imageWidth: Int = 0
    @Published var imageHeight: Int = 0
    
    // Camera quality configuration
    enum CameraQuality {
        case maximum    // .photo preset (~12MP, best for OCR/MRZ)
        case high4K     // .hd4K3840x2160
        case fullHD     // .hd1920x1080 (good balance)
        case hd         // .hd1280x720 (faster processing)
        case balanced   // .high (system optimized)
        
        var preset: AVCaptureSession.Preset {
            switch self {
            case .maximum: return .photo
            case .high4K: return .hd4K3840x2160
            case .fullHD: return .hd1920x1080
            case .hd: return .hd1280x720
            case .balanced: return .high
            }
        }
        
        var description: String {
            switch self {
            case .maximum: return "Maximum Quality (~12MP, best for OCR/MRZ)"
            case .high4K: return "4K Quality (3840×2160)"
            case .fullHD: return "Full HD (1920×1080, good balance)"
            case .hd: return "HD (1280×720, faster processing)"
            case .balanced: return "Balanced (system optimized)"
            }
        }
    }
    
    private var currentQuality: CameraQuality = .maximum
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    // Vision requests for detection
    private let faceRequest = VNDetectFaceRectanglesRequest()
    private let rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.80
        request.maximumObservations = 5
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 5.0
        request.minimumSize = 0.05
        return request
    }()
    
    // MRZ Scanner components
    private let cvr = CaptureVisionRouter()
    private let model = ParsedItemModel()
    
    override init() {
        super.init()
        setupCamera()
        setLicense()
    }
    
    deinit {
        cleanup()
    }
}
```

### Camera Configuration

Add camera setup and quality management:

```swift
extension CameraManager {
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // Set camera quality
        let preferredPreset = currentQuality.preset
        if captureSession.canSetSessionPreset(preferredPreset) {
            captureSession.sessionPreset = preferredPreset
            print("Using camera quality: \(currentQuality.description)")
        } else {
            // Fallback to best available quality
            captureSession.sessionPreset = .photo
        }
        
        // Configure camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                  for: .video, 
                                                  position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }
        
        // Optimize camera settings for document scanning
        configureCameraOptimization(camera: camera)
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Configure video output
        setupVideoOutput()
        
        captureSession.commitConfiguration()
        
        // Create preview layer
        DispatchQueue.main.async { [weak self] in
            self?.createPreviewLayer()
        }
    }
    
    private func configureCameraOptimization(camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
            
            // Auto-focus for sharp text
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            
            // Auto-exposure for consistent lighting
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            
            // White balance for accurate colors
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            camera.unlockForConfiguration()
        } catch {
            print("Failed to configure camera settings: \(error)")
        }
    }
    
    private func setupVideoOutput() {
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Configure video connection
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
        }
    }
    
    private func createPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, 
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        previewLayer = layer
    }
}
```

## Step 3: Real-time Detection with Vision Framework

Implement the video processing delegate:

```swift
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, 
                      didOutput sampleBuffer: CMSampleBuffer, 
                      from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            return 
        }
        
        // Create Vision request handler
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                          orientation: .right,
                                          options: [:])
        
        do {
            // Perform face and rectangle detection
            try handler.perform([faceRequest, rectangleRequest])
            
            let faces = (faceRequest.results as? [VNFaceObservation]) ?? []
            let rectangles = (rectangleRequest.results as? [VNRectangleObservation]) ?? []
            
            // Filter and process rectangles
            let processedRectangles = processRectangles(rectangles)
            
            // Update UI on main thread (throttled)
            updateDetectionResults(faces: faces, rectangles: processedRectangles)
            
        } catch {
            print("Vision detection failed: \(error)")
        }
    }
    
    private func processRectangles(_ rectangles: [VNRectangleObservation]) -> [VNRectangleObservation] {
        return rectangles
            .filter { $0.confidence > 0.70 }
            .sorted { 
                ($0.boundingBox.width * $0.boundingBox.height) > 
                ($1.boundingBox.width * $1.boundingBox.height) 
            }
            .prefix(1)
            .map { $0 }
    }
    
    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 15.0 // 15 FPS
    
    private func updateDetectionResults(faces: [VNFaceObservation], 
                                      rectangles: [VNRectangleObservation]) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastUpdateTime >= updateInterval else { return }
        
        lastUpdateTime = currentTime
        
        DispatchQueue.main.async { [weak self] in
            self?.detectedFaces = faces
            self?.detectedRectangles = rectangles
        }
    }
}
```

## Step 4: OCR Service with Vision Framework

Create a dedicated OCR service:

```swift
import Vision
import UIKit

class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    func extractText(from image: UIImage, completion: @escaping ([String]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("OCR Error: \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let extractedText = observations.compactMap { observation in
                    return observation.topCandidates(1).first?.string
                }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                DispatchQueue.main.async {
                    completion(extractedText)
                }
            }
            
            // Configure OCR for better accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("OCR processing failed: \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
}
```

## Step 5: Document Image Rectification

Implement perspective correction for captured documents:

```swift
import CoreImage
import UIKit
import Vision

struct ImageRectifier {
    static func rectifyImage(_ image: UIImage, 
                           with rectangle: VNRectangleObservation) -> UIImage? {
        
        guard let cgImage = image.cgImage else { return nil }
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        
        // Convert normalized coordinates to image coordinates
        let topLeft = convertPoint(rectangle.topLeft, imageSize: imageSize)
        let topRight = convertPoint(rectangle.topRight, imageSize: imageSize)
        let bottomLeft = convertPoint(rectangle.bottomLeft, imageSize: imageSize)
        let bottomRight = convertPoint(rectangle.bottomRight, imageSize: imageSize)
        
        // Create CIImage for perspective correction
        let ciImage = CIImage(cgImage: cgImage)
        
        // Apply perspective correction
        let correctedImage = applyPerspectiveCorrection(
            to: ciImage,
            topLeft: topLeft,
            topRight: topRight,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight
        )
        
        return correctedImage
    }
    
    private static func convertPoint(_ point: CGPoint, 
                                   imageSize: CGSize) -> CGPoint {
        return CGPoint(
            x: point.x * imageSize.width,
            y: (1 - point.y) * imageSize.height
        )
    }
    
    private static func applyPerspectiveCorrection(to image: CIImage,
                                                 topLeft: CGPoint,
                                                 topRight: CGPoint,
                                                 bottomLeft: CGPoint,
                                                 bottomRight: CGPoint) -> UIImage? {
        
        // Calculate target rectangle dimensions
        let width = max(
            distance(topLeft, topRight),
            distance(bottomLeft, bottomRight)
        )
        let height = max(
            distance(topLeft, bottomLeft),
            distance(topRight, bottomRight)
        )
        
        // Define target corners (standard rectangle)
        let targetSize = CGSize(width: width, height: height)
        let targetTopLeft = CGPoint(x: 0, y: targetSize.height)
        let targetTopRight = CGPoint(x: targetSize.width, y: targetSize.height)
        let targetBottomLeft = CGPoint(x: 0, y: 0)
        let targetBottomRight = CGPoint(x: targetSize.width, y: 0)
        
        // Apply perspective correction filter
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
            return nil
        }
        
        perspectiveFilter.setValue(image, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        guard let outputImage = perspectiveFilter.outputImage else { return nil }
        
        // Convert back to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, 
                                                from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private static func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
}
```

## Step 6: SwiftUI Camera Interface

Create the main camera view with real-time overlays:

```swift
import SwiftUI

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isProcessing = false
    @State private var processingStage = ""
    @State private var capturedImage: UIImage?
    @State private var ocrResults: [String] = []
    @State private var mrzResults: [String: String] = [:]
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Detection overlays
            OverlayView(
                faces: cameraManager.detectedFaces,
                rectangles: cameraManager.detectedRectangles,
                imageWidth: cameraManager.imageWidth,
                imageHeight: cameraManager.imageHeight
            )
            
            // Processing animation overlay
            if isProcessing {
                ProcessingOverlay(stage: processingStage)
            }
            
            // Capture button
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: captureImage) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    .disabled(isProcessing)
                    .scaleEffect(isProcessing ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isProcessing)
                    
                    Spacer()
                }
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
        guard !isProcessing else { return }
        
        // Start processing animation
        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = true
            processingStage = "Capturing..."
        }
        
        cameraManager.capturePhoto { image in
            guard let capturedImage = image else {
                finishProcessing()
                return
            }
            
            self.capturedImage = capturedImage
            processImage(capturedImage)
        }
    }
    
    private func processImage(_ image: UIImage) {
        // Stage 1: Document rectification
        updateProcessingStage("Rectifying document...")
        
        let finalImage: UIImage
        if let rectangle = cameraManager.detectedRectangles.first {
            finalImage = ImageRectifier.rectifyImage(image, with: rectangle) ?? image
        } else {
            finalImage = image
        }
        
        // Stage 2: OCR processing
        updateProcessingStage("Extracting text...")
        
        OCRService.shared.extractText(from: finalImage) { [self] ocrResults in
            self.ocrResults = ocrResults
            
            // Stage 3: MRZ processing
            updateProcessingStage("Processing MRZ...")
            
            cameraManager.processMRZOnImage(finalImage) { [self] mrzResults in
                self.mrzResults = mrzResults
                
                // Complete processing
                updateProcessingStage("Complete!")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    finishProcessing()
                    navigateToResults(image: finalImage)
                }
            }
        }
    }
    
    private func updateProcessingStage(_ stage: String) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                processingStage = stage
            }
        }
    }
    
    private func finishProcessing() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = false
            processingStage = ""
        }
    }
    
    private func navigateToResults(image: UIImage) {
        let imageData = CapturedImageData(
            image: image,
            ocrResults: ocrResults,
            mrzResults: mrzResults
        )
        navigationPath.append(imageData)
    }
}
```

## Step 7: Visual Feedback with Overlay View

Create beautiful detection overlays:

```swift
import SwiftUI
import Vision

struct OverlayView: View {
    let faces: [VNFaceObservation]
    let rectangles: [VNRectangleObservation]
    let imageWidth: Int
    let imageHeight: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Face detection overlays
                ForEach(faces.indices, id: \.self) { index in
                    let face = faces[index]
                    let boundingBox = convertBoundingBox(
                        face.boundingBox,
                        to: geometry.size
                    )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: boundingBox.width, height: boundingBox.height)
                        .position(x: boundingBox.midX, y: boundingBox.midY)
                        .overlay(
                            Text("👤")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .position(x: boundingBox.minX + 15, y: boundingBox.minY + 15)
                        )
                }
                
                // Document detection overlays
                ForEach(rectangles.indices, id: \.self) { index in
                    let rectangle = rectangles[index]
                    
                    DocumentOutline(
                        rectangle: rectangle,
                        viewSize: geometry.size
                    )
                }
            }
        }
    }
    
    private func convertBoundingBox(_ boundingBox: CGRect, 
                                  to viewSize: CGSize) -> CGRect {
        let flippedY = 1 - boundingBox.origin.y - boundingBox.height
        
        return CGRect(
            x: boundingBox.origin.x * viewSize.width,
            y: flippedY * viewSize.height,
            width: boundingBox.width * viewSize.width,
            height: boundingBox.height * viewSize.height
        )
    }
}

struct DocumentOutline: View {
    let rectangle: VNRectangleObservation
    let viewSize: CGSize
    
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        let corners = [
            convertPoint(rectangle.topLeft),
            convertPoint(rectangle.topRight),
            convertPoint(rectangle.bottomRight),
            convertPoint(rectangle.bottomLeft)
        ]
        
        ZStack {
            // Main outline
            Path { path in
                path.move(to: corners[0])
                for corner in corners.dropFirst() {
                    path.addLine(to: corner)
                }
                path.closeSubpath()
            }
            .stroke(
                LinearGradient(
                    colors: [.green, .green.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 3, dash: [10, 5])
            )
            
            // Corner indicators
            ForEach(corners.indices, id: \.self) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .position(corners[index])
                    .scaleEffect(1.0 + sin(animationPhase + Double(index) * 0.5) * 0.2)
            }
            
            // Confidence indicator
            Text(String(format: "%.0f%%", rectangle.confidence * 100))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .position(
                    x: (corners[0].x + corners[1].x) / 2,
                    y: min(corners[0].y, corners[1].y) - 20
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever()) {
                animationPhase = .pi * 2
            }
        }
    }
    
    private func convertPoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * viewSize.width,
            y: (1 - point.y) * viewSize.height
        )
    }
}
```

## Step 8: Processing Animation

Create an engaging processing overlay:

```swift
struct ProcessingOverlay: View {
    let stage: String
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated spinner
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotationAngle))
                }
                .scaleEffect(pulseScale)
                
                // Stage text
                Text(stage)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseScale)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: pulseScale
                            )
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }
}
```

## Step 9: Results Display

Create a comprehensive results view:

```swift
struct ResultView: View {
    let image: UIImage
    let ocrResults: [String]
    let mrzResults: [String: String]
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .padding()
                
                // Results tabs
                Picker("Results", selection: $selectedTab) {
                    Text("OCR Text").tag(0)
                    Text("MRZ Data").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Results content
                TabView(selection: $selectedTab) {
                    OCRResultsView(results: ocrResults)
                        .tag(0)
                    
                    MRZResultsView(results: mrzResults)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Scan Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    shareButton
                }
            }
        }
    }
    
    private var shareButton: some View {
        Button(action: shareResults) {
            Image(systemName: "square.and.arrow.up")
        }
    }
    
    private func shareResults() {
        let text = """
        OCR Results:
        \(ocrResults.joined(separator: "\n"))
        
        MRZ Results:
        \(mrzResults.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

struct OCRResultsView: View {
    let results: [String]
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if results.isEmpty {
                    Text("No text detected")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(results.indices, id: \.self) { index in
                        Text(results[index])
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
    }
}

struct MRZResultsView: View {
    let results: [String: String]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No MRZ data detected")
                            .foregroundColor(.secondary)
                        
                        Text("MRZ processing requires a valid license")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else {
                    ForEach(Array(results.keys.sorted()), id: \.self) { key in
                        MRZDataRow(key: key, value: results[key] ?? "")
                    }
                }
            }
            .padding()
        }
    }
}

struct MRZDataRow: View {
    let key: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
```

## Step 10: MRZ Integration

Configure the MRZ scanner in your CameraManager:

```swift
extension CameraManager: LicenseVerificationListener {
    func setLicense() {
        // Replace with your actual Dynamsoft license key
        // Example format: "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUi..."
        LicenseManager.initLicense(
            "YOUR_DYNAMSOFT_LICENSE_KEY",
            verificationDelegate: self
        )
    }
    
    func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
        if !isSuccess {
            if let error = error {
                print("License verification failed: \(error.localizedDescription)")
            }
        } else {
            print("License verified successfully")
        }
    }
    
    // Process MRZ on captured/normalized image instead of real-time
    func processMRZOnImage(_ image: UIImage, completion: @escaping ([String: String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion([:])
                return
            }
            
            autoreleasepool {
                // Process with MRZ scanner using simplified Dynamsoft API
                let result = self.cvr.captureFromImage(image, templateName: "ReadPassportAndId")
                
                // Process MRZ results
                var mrzData: [String: String] = [:]
                if let item = result.parsedResult?.items?.first, self.model.isLegalMRZ(item) {
                    mrzData = [
                        "Document Type": self.model.documentType,
                        "Document Number": self.model.documentNumber,
                        "Name": self.model.name,
                        "Gender": self.model.gender,
                        "Age": self.model.age != -1 ? String(self.model.age) : "Unknown",
                        "Issuing State": self.model.issuingState,
                        "Nationality": self.model.nationality,
                        "Date of Birth": self.model.dateOfBirth,
                        "Date of Expiry": self.model.dateOfExpiry,
                    ]
                }
                
                DispatchQueue.main.async {
                    completion(mrzData)
                }
            }
        }
    }
}
```

### Key Improvements in Latest MRZ Implementation

The updated MRZ implementation offers several advantages over complex manual conversion approaches:

#### 🚀 **Simplified API Usage**
- **Direct Image Processing**: Uses `cvr.captureFromImage()` instead of manual `ImageData` conversion
- **Reduced Code Complexity**: Eliminates the need for manual CGContext creation and pixel buffer handling
- **Better Performance**: Dynamsoft's optimized internal image processing

#### 💡 **Enhanced Error Handling**
```swift
func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
    if !isSuccess {
        if let error = error {
            print("License verification failed: \(error.localizedDescription)")
        }
    } else {
        print("License verified successfully")
    }
}
```

#### 🔧 **Memory Efficiency**
- **autoreleasepool**: Ensures proper memory cleanup during processing
- **Background Processing**: Uses `.userInitiated` QoS for responsive performance
- **Immediate Cleanup**: No manual buffer management required

## Performance Optimization Tips

### Memory Management
1. **Use autoreleasepool** for image processing operations
2. **Implement proper cleanup** in deinit methods
3. **Process MRZ on-demand** rather than real-time to prevent memory issues
4. **Throttle UI updates** to maintain smooth performance

### Camera Optimization
1. **Choose appropriate quality settings** based on use case
2. **Enable video stabilization** for steadier captures
3. **Configure auto-focus and exposure** for document scanning
4. **Use background queues** for heavy processing

### Vision Framework Tips
1. **Reuse Vision requests** instead of creating new ones
2. **Set appropriate confidence thresholds** to filter noise
3. **Limit maximum observations** to improve performance
4. **Cache processed results** when possible

## Troubleshooting Common Issues

### Camera Not Working
- Verify device permissions in Settings
- Test on physical device (not simulator)
- Check camera privacy settings

### Poor Detection Accuracy
- Ensure good lighting conditions
- Use maximum camera quality for documents
- Adjust detection confidence thresholds
- Ensure documents are flat and well-positioned

### Memory Issues
- Enable on-demand processing instead of real-time
- Implement proper cleanup in deinit
- Use autoreleasepool for image processing
- Monitor memory usage in Instruments

### MRZ License Issues
- Verify license key is correct and properly formatted
- Check network connectivity for license validation
- Ensure license covers MRZ functionality
- Contact Dynamsoft support if needed

## Conclusion

You've now built a comprehensive document scanning app with advanced features:

- ✅ **Real-time camera preview** with optimized settings
- ✅ **Face and document detection** using Vision framework  
- ✅ **OCR text extraction** with high accuracy
- ✅ **Document rectification** for perspective correction
- ✅ **MRZ processing** for official documents
- ✅ **Professional UI** with smooth animations
- ✅ **Memory-efficient architecture** preventing crashes

This app demonstrates modern iOS development best practices and can serve as a foundation for more complex document processing applications.

## Next Steps

To further enhance your app, consider adding:

1. **Batch processing** for multiple documents
2. **Cloud storage integration** for document backup
3. **PDF generation** from scanned documents
4. **Advanced image filters** for better quality
5. **Barcode/QR code scanning** capabilities
6. **Machine learning models** for document classification

## Resources

- [Apple Vision Framework Documentation](https://developer.apple.com/documentation/vision)
- [AVFoundation Camera Guide](https://developer.apple.com/documentation/avfoundation)
- [Dynamsoft MRZ Scanner Documentation](https://www.dynamsoft.com/capture-vision/docs/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Core Image Filters Reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/)

Happy coding! 🚀

