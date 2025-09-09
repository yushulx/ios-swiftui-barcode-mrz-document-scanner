import AVFoundation
import UIKit
import Vision

class CameraManager: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var detectedFaces: [VNFaceObservation] = []
    @Published var detectedRectangles: [VNRectangleObservation] = []
    @Published var isSessionRunning = false
    
    // Debug properties
    @Published var currentFrameSize: CGSize = .zero
    @Published var currentFrameThumbnail: UIImage?
    @Published var frameOrientation: String = ""
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var photoCaptureDelegate: PhotoCaptureDelegate?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // Set session preset for better quality
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }
        
        // Add video input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to create camera input")
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Add photo output for capture
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.main.async {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            self.previewLayer?.videoGravity = .resizeAspectFill
            
            // Configure video orientation for portrait
            if let connection = self.previewLayer?.connection {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            print("Preview layer created with portrait orientation")
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            if !(self?.captureSession.isRunning ?? false) {
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            if self?.captureSession.isRunning ?? false {
                self?.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self?.isSessionRunning = false
                }
            }
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        // Store the delegate to prevent deallocation
        photoCaptureDelegate = PhotoCaptureDelegate { [weak self] image in
            DispatchQueue.main.async {
                completion(image)
                self?.photoCaptureDelegate = nil // Clean up after completion
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: photoCaptureDelegate!)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Update frame debug info
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        let frameSize = CGSize(width: frameWidth, height: frameHeight)
        
        // Create thumbnail every 30 frames (roughly once per second)
        let frameCount = arc4random_uniform(30)
        if frameCount == 0 {
            let thumbnail = createThumbnail(from: pixelBuffer)
            DispatchQueue.main.async {
                self.currentFrameSize = frameSize
                self.currentFrameThumbnail = thumbnail
                self.frameOrientation = "Vision: .right, Preview: portrait, Frame: \(frameWidth)x\(frameHeight)"
            }
        }
        
        let faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation] else { return }
            DispatchQueue.main.async {
                self?.detectedFaces = results
            }
        }
        
        let rectangleRequest = VNDetectRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNRectangleObservation] else { return }
            
            // Simply find the largest rectangle with decent confidence
            let filteredResults = results
                .filter { $0.confidence > 0.7 } // Reasonable confidence threshold
                .filter { rectangle in
                    let boundingBox = rectangle.boundingBox
                    // Basic size filter - must be reasonably large
                    return boundingBox.width > 0.1 && boundingBox.height > 0.1
                }
                .filter { rectangle in
                    // Ensure all corners are within bounds
                    let corners = [rectangle.topLeft, rectangle.topRight, rectangle.bottomRight, rectangle.bottomLeft]
                    return corners.allSatisfy { corner in
                        corner.x >= 0 && corner.x <= 1 && corner.y >= 0 && corner.y <= 1
                    }
                }
                .sorted { rect1, rect2 in
                    // Sort by area (largest first) - this is the key change
                    let area1 = rect1.boundingBox.width * rect1.boundingBox.height
                    let area2 = rect2.boundingBox.width * rect2.boundingBox.height
                    return area1 > area2
                }
            
            DispatchQueue.main.async {
                // Show only the largest rectangle
                self?.detectedRectangles = Array(filteredResults.prefix(1))
            }
        }
        
        // Permissive rectangle detection settings - no aspect ratio restrictions
        rectangleRequest.minimumAspectRatio = 0.2  // Very permissive
        rectangleRequest.maximumAspectRatio = 5.0  // Very permissive  
        rectangleRequest.minimumSize = 0.05        // Smaller minimum size
        rectangleRequest.maximumObservations = 5   // More candidates to choose from
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        do {
            try handler.perform([faceRequest, rectangleRequest])
        } catch {
            print("Failed to perform vision requests: \(error)")
        }
    }
    
    private func createThumbnail(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // Create a small thumbnail (100x100 max)
        let thumbnailSize: CGFloat = 100
        let scale = min(thumbnailSize / ciImage.extent.width, thumbnailSize / ciImage.extent.height)
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Photo Capture Delegate
class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        
        completion(image)
    }
}
