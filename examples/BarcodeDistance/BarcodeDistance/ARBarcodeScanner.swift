import SwiftUI
import ARKit
import Vision

import DynamsoftBarcodeReaderBundle

struct BarcodeDetection: Identifiable {
    let id = UUID()
    let value: String
    let type: String
    let distance: Float
    let position: CGPoint
    let bounds: CGRect
}

class ARBarcodeScannerCoordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
    var parent: ARBarcodeScanner
    var detectedBarcodes: [BarcodeDetection] = []
    var isProcessing = false
    var lastProcessTime: TimeInterval = 0
    let processingInterval: TimeInterval = 0.1 // Process every 100ms instead of every frame
    let cvr = CaptureVisionRouter()
    weak var arView: ARSCNView? // Keep reference to AR view
    
    init(parent: ARBarcodeScanner) {
        self.parent = parent
        super.init()
        setLicense()
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Throttle processing to reduce CPU usage
        let currentTime = Date().timeIntervalSince1970
        guard !isProcessing && (currentTime - lastProcessTime) >= processingInterval else { return }
        
        isProcessing = true
        lastProcessTime = currentTime
        
        // Get orientation on main thread before going to background
        let currentOrientation: UIInterfaceOrientation
        if Thread.isMainThread {
            currentOrientation = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.interfaceOrientation ?? .portrait
        } else {
            currentOrientation = .portrait // Default fallback
        }
        
        // Process barcode detection in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.detectBarcodes(in: frame, orientation: currentOrientation)
            self?.isProcessing = false
        }
    }
    
    private func detectBarcodes(in frame: ARFrame, orientation: UIInterfaceOrientation) {
        let pixelBuffer = frame.capturedImage
        
        // Get AR view size for coordinate scaling
        let viewInfo = getARViewSize()
        let arViewPointSize = viewInfo.pointSize
        let arViewPixelSize = viewInfo.pixelSize
        let screenScale = viewInfo.scale
        
        // Lock the pixel buffer for reading
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Failed to get base address from pixel buffer")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let bufferSize = CVPixelBufferGetDataSize(pixelBuffer)
        
        // Get Dynamsoft orientation based on device orientation
        let dynamsoftOrientation = getDynamsoftOrientation(for: orientation)
        
        let buffer = Data(bytes: baseAddress, count: bufferSize)
        
        // Convert pixel format to Dynamsoft ImagePixelFormat
        let dynamsoftFormat: ImagePixelFormat
        switch pixelFormat {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            dynamsoftFormat = .NV12
        case kCVPixelFormatType_32BGRA:
            dynamsoftFormat = .ARGB8888
        case kCVPixelFormatType_32ARGB:
            dynamsoftFormat = .ARGB8888
        default:
            print("Unsupported pixel format: \(pixelFormat), trying NV12")
            dynamsoftFormat = .NV12
        }
        
        let imageData = ImageData(
            bytes: buffer, width: UInt(width), height: UInt(height),
            stride: UInt(width), format: dynamsoftFormat, orientation: dynamsoftOrientation, tag: nil)
        let result = cvr.captureFromBuffer(
            imageData, templateName: PresetTemplate.readBarcodes.rawValue)

        var barcodeArray: [[String: Any]] = []
        if let items = result.items, items.count > 0 {

            for item in items {
                if item.type == .barcode, let barcodeItem = item as? BarcodeResultItem {
                    let format = barcodeItem.formatString
                    let text = barcodeItem.text
                    let points = barcodeItem.location.points

                    // Map points to a dictionary format
                    let pointArray: [[String: CGFloat]] = points.compactMap { point in
                        guard let cgPoint = point as? CGPoint else { return nil }
                        return ["x": cgPoint.x, "y": cgPoint.y]
                    }

                    // Create dictionary for barcode data
                    let barcodeData: [String: Any] = [
                        "format": format,
                        "text": text,
                        "points": pointArray,
                    ]

                    // Append barcode data to array
                    barcodeArray.append(barcodeData)
                }
            }
        }
        
        // Process Dynamsoft results and convert to BarcodeDetection objects
        var detections: [BarcodeDetection] = []
        
        for barcodeData in barcodeArray {
            guard let format = barcodeData["format"] as? String,
                  let text = barcodeData["text"] as? String,
                  let pointsArray = barcodeData["points"] as? [[String: CGFloat]] else {
                continue
            }
            
            // Convert points to CGPoint array
            let points: [CGPoint] = pointsArray.compactMap { pointDict in
                guard let x = pointDict["x"], let y = pointDict["y"] else { return nil }
                return CGPoint(x: x, y: y)
            }
            
            guard points.count >= 4 else { continue }
            
            // Get orientation-aware camera dimensions
            let (cameraWidth, cameraHeight) = getOrientedCameraDimensions(
                bufferWidth: width, 
                bufferHeight: height, 
                orientation: orientation
            )
            
            // Calculate scale factor to convert from camera resolution to AR view size
            // Use pixel size for accurate coordinate mapping
            let scaleX = arViewPixelSize.width / CGFloat(cameraWidth)
            let scaleY = arViewPixelSize.height / CGFloat(cameraHeight)
            let scale = max(scaleX, scaleY) // Use larger scale to fill entire view (crop)
            
            // Calculate the cropping offset (how much is cropped from each side)
            let scaledImageWidth = CGFloat(cameraWidth) * scale
            let scaledImageHeight = CGFloat(cameraHeight) * scale
            let cropOffsetX = (scaledImageWidth - arViewPixelSize.width) / 2
            let cropOffsetY = (scaledImageHeight - arViewPixelSize.height) / 2
            
            // Scale points and adjust for cropping (working in pixel space)
            let scaledPixelPoints = points.map { point in
                CGPoint(
                    x: point.x * scale - cropOffsetX,
                    y: point.y * scale - cropOffsetY
                )
            }
            
            // Convert pixel coordinates back to point coordinates for UI
            let scaledPoints = scaledPixelPoints.map { pixelPoint in
                CGPoint(
                    x: pixelPoint.x / screenScale,
                    y: pixelPoint.y / screenScale
                )
            }
            
            // Calculate bounding box from scaled points (now in point coordinates)
            let minX = scaledPoints.map { $0.x }.min() ?? 0
            let maxX = scaledPoints.map { $0.x }.max() ?? 0
            let minY = scaledPoints.map { $0.y }.min() ?? 0
            let maxY = scaledPoints.map { $0.y }.max() ?? 0
            
            // Create screen bounds directly from scaled coordinates, adjusted for safe area
            let screenBounds = CGRect(
                x: minX,
                y: minY - 240,
                width: maxX - minX,
                height: maxY - minY
            )
            
            let screenCenter = CGPoint(
                x: screenBounds.midX,
                y: screenBounds.midY
            )
            
            // Convert center to normalized coordinates for distance calculation
            let normalizedCenter = CGPoint(
                x: screenCenter.x / arViewPointSize.width,
                y: 1 - (screenCenter.y / arViewPointSize.height) // Flip Y coordinate for ARKit
            )
            
            // Calculate distance using ARKit hit test
            if let distance = self.calculateDistance(at: normalizedCenter, frame: frame) {
                let detection = BarcodeDetection(
                    value: text,
                    type: format,
                    distance: distance,
                    position: screenCenter,
                    bounds: screenBounds
                )
                detections.append(detection)
            }
        }
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.parent.detectedBarcodes = detections
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
    
    // Get AR view size in actual pixels (not points)
    private func getARViewSize() -> (pointSize: CGSize, pixelSize: CGSize, scale: CGFloat) {
        var pointSize: CGSize = CGSize(width: 393, height: 852) // Default iPhone size in points
        var screenScale: CGFloat = 3.0 // Default to 3x for modern iPhones
        
        DispatchQueue.main.sync {
            // First try to get the actual AR view size
            if let arView = self.arView {
                pointSize = arView.bounds.size
                screenScale = arView.contentScaleFactor
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                pointSize = window.bounds.size
                screenScale = window.screen.scale
            }
        }
        
        // Convert points to pixels
        let pixelSize = CGSize(
            width: pointSize.width * screenScale,
            height: pointSize.height * screenScale
        )
        
        return (pointSize: pointSize, pixelSize: pixelSize, scale: screenScale)
    }
    
    // Get camera dimensions based on orientation
    private func getOrientedCameraDimensions(bufferWidth: Int, bufferHeight: Int, orientation: UIInterfaceOrientation) -> (width: Int, height: Int) {
        // Camera buffer is always in landscape orientation (e.g., 1920x1080)
        // We need to swap dimensions based on device orientation
        
        switch orientation {
        case .portrait, .portraitUpsideDown:
            // In portrait, camera should appear as 1080x1920 (width x height)
            return (width: min(bufferWidth, bufferHeight), height: max(bufferWidth, bufferHeight))
            
        case .landscapeLeft, .landscapeRight:
            // In landscape, camera should appear as 1920x1080 (width x height)
            return (width: max(bufferWidth, bufferHeight), height: min(bufferWidth, bufferHeight))
            
        default:
            // Default to portrait
            return (width: min(bufferWidth, bufferHeight), height: max(bufferWidth, bufferHeight))
        }
    }
    
    // Get Dynamsoft orientation value based on device orientation
    private func getDynamsoftOrientation(for orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .portrait:
            return 90   // Normal orientation
        case .portraitUpsideDown:
            return 270 // Upside down
        case .landscapeLeft:
            return 180 // Rotated left
        case .landscapeRight:
            return 0  // Rotated right
        default:
            return 0   // Default to portrait
        }
    }
    
    private func calculateDistance(at point: CGPoint, frame: ARFrame) -> Float? {
        // Try multiple hit test types for better accuracy
        var results = frame.hitTest(point, types: .featurePoint)
        
        // If no feature points found, try existing plane
        if results.isEmpty {
            results = frame.hitTest(point, types: .existingPlane)
        }
        
        // If still no results, try estimated plane
        if results.isEmpty {
            results = frame.hitTest(point, types: .estimatedHorizontalPlane)
        }
        
        guard let result = results.first else {
            // Fallback: estimate distance based on barcode size if hit test fails
            return nil
        }
        
        // Get the distance from the camera
        let distance = simd_distance(result.worldTransform.columns.3, frame.camera.transform.columns.3)
        
        // Sanity check - reject unrealistic distances
        guard distance > 0.1 && distance < 10.0 else {
            return nil
        }
        
        return distance
    }
    
    private func getBarcodeTypeName(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr:
            return "QR Code"
        case .code128:
            return "Code 128"
        case .code39:
            return "Code 39"
        case .code93:
            return "Code 93"
        case .ean8:
            return "EAN-8"
        case .ean13:
            return "EAN-13"
        case .upce:
            return "UPC-E"
        case .pdf417:
            return "PDF417"
        case .aztec:
            return "Aztec"
        case .dataMatrix:
            return "Data Matrix"
        case .i2of5:
            return "I2of5"
        case .itf14:
            return "ITF14"
        case .code39Checksum:
            return "Code 39 Checksum"
        case .code39FullASCII:
            return "Code 39 Full ASCII"
        case .code39FullASCIIChecksum:
            return "Code 39 Full ASCII Checksum"
        case .code93i:
            return "Code 93i"
        case .microPDF417:
            return "Micro PDF417"
        case .microQR:
            return "Micro QR"
        case .gs1DataBar:
            return "GS1 DataBar"
        case .gs1DataBarExpanded:
            return "GS1 DataBar Expanded"
        case .gs1DataBarLimited:
            return "GS1 DataBar Limited"
        default:
            return "Unknown"
        }
    }
}

extension ARBarcodeScannerCoordinator: LicenseVerificationListener {
    
    func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
        if !isSuccess {
            if let error = error {
                print("\(error.localizedDescription)")
            }
        }
    }

    func setLicense() {
        LicenseManager.initLicense(
            "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ==",
            verificationDelegate: self)
    }
}

struct ARBarcodeScanner: UIViewRepresentable {
    @Binding var detectedBarcodes: [BarcodeDetection]
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator
        
        // Store reference to AR view in coordinator
        context.coordinator.arView = arView
        
        // Configure AR session with optimized settings
        let configuration = ARWorldTrackingConfiguration()
        
        // Reduce resource usage - we only need basic tracking for distance
        configuration.planeDetection = [] // Disable plane detection for better performance
        configuration.environmentTexturing = .none // Disable environment texturing
        
        // Enable auto focus for better barcode scanning
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> ARBarcodeScannerCoordinator {
        ARBarcodeScannerCoordinator(parent: self)
    }
    
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ARBarcodeScannerCoordinator) {
        uiView.session.pause()
    }
}
