import AVFoundation
import UIKit
import Vision
import ImageIO
import DynamsoftMRZScannerBundle

final class CameraManager: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var detectedFaces: [VNFaceObservation] = []
    @Published var detectedRectangles: [VNRectangleObservation] = []
    // Remove real-time MRZ processing - only process on capture
    // @Published var mrzContour: [CGPoint] = []
    // @Published var mrzResults: [String: String] = []
    @Published var isSessionRunning = false
    
    // Image dimensions for coordinate conversion
    @Published var imageWidth: Int = 0
    @Published var imageHeight: Int = 0
    
    // Store the latest frame for capture
    private var latestSampleBuffer: CMSampleBuffer?
    private var captureCompletion: ((UIImage?) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    // Remove MRZ processing queue - only needed for capture
    // private let mrzQueue = DispatchQueue(label: "mrz.processing.queue", qos: .userInitiated)

    // Vision requests (reused)
    private let faceRequest = VNDetectFaceRectanglesRequest()
    private let rectangleRequest: VNDetectRectanglesRequest = {
        let r = VNDetectRectanglesRequest()
        r.minimumConfidence = 0.80
        r.maximumObservations = 5
        // Loose detector settings; we’ll still post-filter
        r.minimumAspectRatio = 0.2
        r.maximumAspectRatio = 5.0
        r.minimumSize = 0.05
        return r
    }()

    // Throttle UI publishes a bit
    private var lastPublishTime: CFTimeInterval = 0
    private let publishInterval: CFTimeInterval = 1.0 / 15.0
    
    // Remove MRZ throttling - only process on capture
    // private var lastMRZProcessTime: CFTimeInterval = 0
    // private let mrzProcessInterval: CFTimeInterval = 1.0 / 15.0
    
    // Dynamsoft MRZ Scanner
    private let cvr = CaptureVisionRouter()
    private let model = ParsedItemModel()

    override init() {
        super.init()
        setupCamera()
        setLicense()
    }
    
    deinit {
        // Clean up resources to prevent memory leaks
        stopSession()
        
        // Clear delegate to break potential retain cycles
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        
        // Clear captured sample buffer
        latestSampleBuffer = nil
        
        // Clear any completion handlers
        captureCompletion = nil
        
        print("CameraManager deallocated")
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }

        // Back camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else {
            captureSession.commitConfiguration()
            return
        }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        // Video output (BGRA for Vision)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Force portrait connection where supported (affects preview, not raw bytes)
        if let vConn = videoOutput.connection(with: .video), vConn.isVideoOrientationSupported {
            vConn.videoOrientation = .portrait
        }

        captureSession.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            layer.videoGravity = .resizeAspectFill
            if let conn = layer.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
            self.previewLayer = layer
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                return
            }
            self.captureSession.startRunning()
            DispatchQueue.main.async { 
                self.isSessionRunning = true 
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                return
            }
            self.captureSession.stopRunning()
            DispatchQueue.main.async { 
                self.isSessionRunning = false 
            }
        }
    }
    
    func cleanup() {
        stopSession()
        
        // Clear all UI state
        DispatchQueue.main.async { [weak self] in
            self?.detectedFaces = []
            self?.detectedRectangles = []
            self?.imageWidth = 0
            self?.imageHeight = 0
        }
        
        // Clear sample buffer and completion
        latestSampleBuffer = nil
        captureCompletion = nil
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        
        guard captureSession.isRunning else {
            completion(nil)
            return
        }
        
        // Store the completion to be called when we get the next frame
        captureCompletion = completion
    }
    
    // Convert sample buffer to properly oriented UIImage for capture
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply orientation correction for .right orientation
        let orientedImage = ciImage.oriented(.right)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(orientedImage, from: orientedImage.extent) else {
            return nil
        }
        
        let image = UIImage(cgImage: cgImage)
        return image
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        // Store the latest frame for potential photo capture (clear old one first)
        latestSampleBuffer = nil  // Clear previous to prevent accumulation
        latestSampleBuffer = sampleBuffer
        
        // If there's a capture completion waiting, process it immediately and clear
        if let completion = captureCompletion {
            captureCompletion = nil
            let image = imageFromSampleBuffer(sampleBuffer)
            DispatchQueue.main.async {
                completion(image)
            }
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Vision handler: portrait + back camera => .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])

        do {
            try handler.perform([faceRequest, rectangleRequest])

            let faces = (faceRequest.results as? [VNFaceObservation]) ?? []
            let rectsRaw = (rectangleRequest.results as? [VNRectangleObservation]) ?? []

            // Post-filter rectangles: decent confidence + largest area
            let rectsFiltered = rectsRaw
                .filter { $0.confidence > 0.70 }
                .filter {
                    let bb = $0.boundingBox
                    return bb.width > 0.10 && bb.height > 0.10
                }
                .sorted {
                    ($0.boundingBox.width * $0.boundingBox.height) >
                    ($1.boundingBox.width * $1.boundingBox.height)
                }
            let top1 = Array(rectsFiltered.prefix(1))

            // Throttle publishes
            let now = CACurrentMediaTime()
            if now - lastPublishTime >= publishInterval {
                lastPublishTime = now
                DispatchQueue.main.async { [weak self] in
                    self?.detectedFaces = faces
                    self?.detectedRectangles = top1
                }
            }
            
            // Remove real-time MRZ processing to save memory and prevent device heating
            // MRZ will only be processed when user captures an image
            
        } catch {
            // Vision processing failed
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
                // Process with MRZ scanner
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

extension CameraManager: LicenseVerificationListener {
    
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
