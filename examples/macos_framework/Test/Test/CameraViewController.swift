import AVFoundation
import Accelerate
import Cocoa
import DCV
import SwiftUI

typealias ViewController = NSViewController
typealias ImageType = NSImage

class CameraViewController: ViewController, AVCapturePhotoCaptureDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    var captureSession: AVCaptureSession!
    var photoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onImageCaptured: ((ImageType) -> Void)?

    let cv = CaptureVisionWrapper()

    private var overlayView: BarcodeOverlayView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize the license here
        let licenseKey =
            "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ=="

        let result = CaptureVisionWrapper.initializeLicense(licenseKey)
        if result == 0 {
            print("License initialized successfully")
        } else {
            print("Failed to initialize license with error code: \(result)")
        }

        // Initialize the overlay view
        overlayView = BarcodeOverlayView()
        overlayView.wantsLayer = true  // Ensure the NSView has a layer
        overlayView.layer?.backgroundColor = NSColor.clear.cgColor
        overlayView.frame = view.bounds
        view.addSubview(overlayView, positioned: .above, relativeTo: nil)

        setupCamera()
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(for: .video) else {
            print("Unable to access the camera!")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            photoOutput = AVCapturePhotoOutput()
            let videoOutput = AVCaptureVideoDataOutput()

            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

            if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)
                captureSession.addOutput(videoOutput)

                // Set up preview layer
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.bounds  // Set frame here

                view.layer = CALayer()
                view.wantsLayer = true
                view.layer?.insertSublayer(previewLayer, at: 0)

                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.startRunning()
                }
            }
        } catch {
            print("Error Unable to initialize camera: \(error.localizedDescription)")
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Extract the pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Process the frame
        processCameraFrame(pixelBuffer)
    }

    func flipBufferVertically(buffer: Data, width: Int, height: Int, bytesPerRow: Int) -> Data {
        var flippedBuffer = Data(capacity: buffer.count)

        for row in 0..<height {
            // Calculate the range of the current row in the buffer
            let start = (height - row - 1) * bytesPerRow
            let end = start + bytesPerRow

            // Append the row from the original buffer to the flipped buffer
            flippedBuffer.append(buffer[start..<end])
        }

        return flippedBuffer
    }

    func flipVertically(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

        guard let srcBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        var srcBuffer = vImage_Buffer(
            data: srcBaseAddress,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )

        guard let dstData = malloc(bytesPerRow * height) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }

        var dstBuffer = vImage_Buffer(
            data: dstData,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )

        // Perform vertical flip
        vImageVerticalReflect_ARGB8888(&srcBuffer, &dstBuffer, 0)

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        // Create a new CVPixelBuffer for the flipped image
        var flippedPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil,
            width,
            height,
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            nil,
            &flippedPixelBuffer
        )

        if let flippedPixelBuffer = flippedPixelBuffer {
            CVPixelBufferLockBaseAddress(flippedPixelBuffer, .readOnly)
            memcpy(
                CVPixelBufferGetBaseAddress(flippedPixelBuffer), dstBuffer.data,
                bytesPerRow * height)
            CVPixelBufferUnlockBaseAddress(flippedPixelBuffer, .readOnly)
        }

        free(dstData)
        return flippedPixelBuffer
    }

    func processCameraFrame(_ pixelBuffer: CVPixelBuffer) {
        // Get camera preview size from pixel buffer
        let previewWidth = CVPixelBufferGetWidth(pixelBuffer)
        let previewHeight = CVPixelBufferGetHeight(pixelBuffer)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayView.cameraPreviewSize = CGSize(width: previewWidth, height: previewHeight)
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        if let baseAddress = baseAddress {
            let barcodeArray =
                cv.captureImage(
                    withData: baseAddress, width: Int32(width), height: Int32(Int(height)),
                    stride: Int32(Int(bytesPerRow)), pixelFormat: PixelFormat.ARGB8888)
                as? [[String: Any]] ?? []

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayView.barcodeData = barcodeArray
                self.overlayView.setNeedsDisplay(self.overlayView.bounds)  // macOS
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }

        guard let data = photo.fileDataRepresentation(),
            let image = ImageType(data: data)
        else {
            return
        }

        onImageCaptured?(image)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if previewLayer != nil {
            previewLayer.frame = view.bounds
        }

        if overlayView != nil {
            overlayView.frame = view.bounds
        }
    }
}
