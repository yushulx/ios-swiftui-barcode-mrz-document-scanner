//
//  ARBarcodeScanner.swift
//  BarcodeDistance
//
//  Created by Xiao Ling on 10/22/25.
//

import SwiftUI
import ARKit
import Vision

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
    let processingInterval: TimeInterval = 0.2 // Process every 200ms instead of every frame
    
    init(parent: ARBarcodeScanner) {
        self.parent = parent
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Throttle processing to reduce CPU usage
        let currentTime = Date().timeIntervalSince1970
        guard !isProcessing && (currentTime - lastProcessTime) >= processingInterval else { return }
        
        isProcessing = true
        lastProcessTime = currentTime
        
        // Process barcode detection in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.detectBarcodes(in: frame)
            self?.isProcessing = false
        }
    }
    
    private func detectBarcodes(in frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Barcode detection error: \(error.localizedDescription)")
                return
            }
            
            guard let results = request.results as? [VNBarcodeObservation] else {
                DispatchQueue.main.async {
                    self.parent.detectedBarcodes = []
                }
                return
            }
            
            var detections: [BarcodeDetection] = []
            
            for observation in results {
                guard let payload = observation.payloadStringValue else { continue }
                
                // Convert Vision coordinates to screen coordinates
                let boundingBox = observation.boundingBox
                let center = CGPoint(
                    x: boundingBox.midX,
                    y: 1 - boundingBox.midY // Flip Y coordinate
                )
                
                // Calculate distance using ARKit hit test
                if let distance = self.calculateDistance(at: center, frame: frame) {
                    let screenBounds = self.convertToScreenCoordinates(boundingBox: boundingBox)
                    let screenCenter = CGPoint(
                        x: screenBounds.midX,
                        y: screenBounds.midY
                    )
                    
                    let barcodeType = self.getBarcodeTypeName(observation.symbology)
                    
                    let detection = BarcodeDetection(
                        value: payload,
                        type: barcodeType,
                        distance: distance,
                        position: screenCenter,
                        bounds: screenBounds
                    )
                    detections.append(detection)
                }
            }
            
            DispatchQueue.main.async {
                self.parent.detectedBarcodes = detections
            }
        }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform barcode detection: \(error.localizedDescription)")
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
    
    private func convertToScreenCoordinates(boundingBox: CGRect) -> CGRect {
        let screenSize = UIScreen.main.bounds.size
        
        // Convert Vision coordinates (0,0 at bottom-left) to screen coordinates (0,0 at top-left)
        let x = boundingBox.minX * screenSize.width
        let y = (1 - boundingBox.maxY) * screenSize.height
        let width = boundingBox.width * screenSize.width
        let height = boundingBox.height * screenSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
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

struct ARBarcodeScanner: UIViewRepresentable {
    @Binding var detectedBarcodes: [BarcodeDetection]
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        arView.session.delegate = context.coordinator
        
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
