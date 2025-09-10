import AVFoundation
import UIKit
import Vision
import ImageIO

final class CameraManager: NSObject, ObservableObject {
    @Published var captureSession = AVCaptureSession()
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var detectedFaces: [VNFaceObservation] = []
    @Published var detectedRectangles: [VNRectangleObservation] = []
    @Published var isSessionRunning = false
    
    // Store the latest frame for capture
    private var latestSampleBuffer: CMSampleBuffer?
    private var captureCompletion: ((UIImage?) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

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
        
        // Store the latest buffer for potential capture
        latestSampleBuffer = sampleBuffer
        
        // If we have a pending capture request, fulfill it now
        if let completion = captureCompletion {
            captureCompletion = nil
            
            // Convert the sample buffer to UIImage
            if let image = imageFromSampleBuffer(sampleBuffer) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
            return
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
        } catch {
            // Vision processing failed
        }
    }
}
