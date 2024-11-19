import AVFoundation
import Accelerate
import SwiftUI

#if os(iOS)
    import UIKit
#endif

#if os(iOS)
    import UIKit
    typealias ViewController = UIViewController
    typealias ImageType = UIImage
#elseif os(macOS)
    import Cocoa
    typealias ViewController = NSViewController
    typealias ImageType = NSImage
#endif

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

        // Initialize the overlay view
        overlayView = BarcodeOverlayView()

        #if os(iOS)
            overlayView.backgroundColor = UIColor.clear
        #elseif os(macOS)
            overlayView.wantsLayer = true  // Ensure the NSView has a layer
            overlayView.layer?.backgroundColor = NSColor.clear.cgColor
        #endif

        // Add the overlay view above the preview layer
        #if os(iOS)
            overlayView.frame = view.bounds
            view.addSubview(overlayView)
        #elseif os(macOS)
            overlayView.frame = view.bounds
            view.addSubview(overlayView, positioned: .above, relativeTo: nil)
        #endif

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
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
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

                #if os(iOS)
                    view.layer.insertSublayer(previewLayer, at: 0)
                #elseif os(macOS)
                    view.layer = CALayer()
                    view.wantsLayer = true
                    view.layer?.insertSublayer(previewLayer, at: 0)
                #endif

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

        let flippedPixelBuffer = flipVertically(pixelBuffer: pixelBuffer) ?? pixelBuffer
        CVPixelBufferLockBaseAddress(flippedPixelBuffer, .readOnly)

        let baseAddress = CVPixelBufferGetBaseAddress(flippedPixelBuffer)
        let width = CVPixelBufferGetWidth(flippedPixelBuffer)
        let height = CVPixelBufferGetHeight(flippedPixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(flippedPixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(flippedPixelBuffer)

        // Pass frame data to C++ via the wrapper
        if let baseAddress = baseAddress {
            let buffer = Data(bytes: baseAddress, count: bytesPerRow * height)
            let barcodeArray =
                cv.captureImage(
                    with: buffer, width: Int32(width), height: Int32(Int(height)),
                    stride: Int32(Int(bytesPerRow)), pixelFormat: pixelFormat)
                as? [[String: Any]] ?? []

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayView.barcodeData = barcodeArray
                #if os(iOS)
                    self.overlayView.setNeedsDisplay()  // iOS
                #elseif os(macOS)
                    self.overlayView.setNeedsDisplay(self.overlayView.bounds)  // macOS
                #endif
            }
        }

        CVPixelBufferUnlockBaseAddress(flippedPixelBuffer, .readOnly)
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        #if os(iOS)
            settings.flashMode = .auto
        #endif
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: AVCapturePhotoCaptureDelegate
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

    // Handle view resizing
    #if os(iOS)
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            if previewLayer != nil {
                previewLayer.frame = view.bounds
            }

            if overlayView != nil {
                overlayView.frame = view.bounds
            }
        }
    #elseif os(macOS)
        override func viewDidLayout() {
            super.viewDidLayout()
            if previewLayer != nil {
                previewLayer.frame = view.bounds
            }

            if overlayView != nil {
                overlayView.frame = view.bounds
            }
        }
    #endif
}
