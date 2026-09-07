import AVFoundation
import Accelerate
import SwiftUI

#if os(iOS)
    import UIKit
    import CoreGraphics
    import DynamsoftCaptureVisionBundle
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

    #if os(iOS)
        let cvr = CaptureVisionRouter()
    #elseif os(macOS)
        let cv = CaptureVisionWrapper()
    #endif

    private var overlayView: BarcodeOverlayView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize the license here
        let licenseKey =
            "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ=="

        #if os(iOS)
            setLicense(license: licenseKey)
        #elseif os(macOS)
            let result = CaptureVisionWrapper.initializeLicense(licenseKey)
            if result == 0 {
                print("License initialized successfully")
            } else {
                print("Failed to initialize license with error code: \(result)")
            }
        #endif

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

    func processCameraFrame(_ pixelBuffer: CVPixelBuffer) {
        // Get camera preview size from pixel buffer
        let previewWidth = CVPixelBufferGetWidth(pixelBuffer)
        let previewHeight = CVPixelBufferGetHeight(pixelBuffer)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.overlayView.cameraPreviewSize = CGSize(width: previewWidth, height: previewHeight)
        }
        #if os(iOS)
            var barcodeArray: [[String: Any]] = []

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                let width = CVPixelBufferGetWidth(pixelBuffer)
                let height = CVPixelBufferGetHeight(pixelBuffer)
                let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

                // Wrap the BGRA frame into ImageData and decode it with the
                // built-in barcode-only preset template.
                let buffer = Data(bytes: baseAddress, count: bytesPerRow * height)
                let imageData = ImageData(
                    bytes: buffer, width: UInt(width), height: UInt(height),
                    stride: UInt(bytesPerRow), format: .ABGR8888, orientation: 0, tag: nil)
                let result = cvr.captureFromBuffer(
                    imageData, templateName: PresetTemplate.readBarcodes.rawValue)

                if let items = result.decodedBarcodesResult?.items, items.count > 0 {
                    print("Decoded Barcode Count: \(items.count)")

                    for barcodeItem in items {
                        let format = barcodeItem.formatString
                        let text = barcodeItem.text
                        let points = barcodeItem.location.points.compactMap { value -> [String: CGFloat]? in
                            let point = value.cgPointValue
                            return ["x": point.x, "y": point.y]
                        }

                        barcodeArray.append([
                            "format": format,
                            "text": text,
                            "points": points,
                        ])

                        // Debugging logs
                        print("Barcode Format: \(format)")
                        print("Barcode Text: \(text)")
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.overlayView.barcodeData = barcodeArray
                self.overlayView.setNeedsDisplay()
            }

        #elseif os(macOS)

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

            // Pass frame data to C++ via the wrapper
            if let baseAddress = baseAddress {
                let barcodeArray =
                    cv.captureImage(
                        withData: baseAddress, width: Int32(width), height: Int32(Int(height)),
                        stride: Int32(Int(bytesPerRow)), pixelFormat: pixelFormat)
                    as? [[String: Any]] ?? []

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.overlayView.barcodeData = barcodeArray
                    self.overlayView.setNeedsDisplay(self.overlayView.bounds)  // macOS
                }
            }

            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        #endif
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

#if os(iOS)
    extension CameraViewController: LicenseVerificationListener {

        func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
            if !isSuccess {
                if let error = error {
                    print("\(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.displayLicenseMessage(
                            message: "License initialization failed：" + error.localizedDescription)
                    }
                }
            }
        }

        func setLicense(license: String) {
            LicenseManager.initLicense(license, verificationDelegate: self)
        }

        func displayLicenseMessage(message: String) {
            let label = UILabel()
            label.text = message
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .red
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.bottomAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                label.leadingAnchor.constraint(
                    greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(
                    lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            ])
        }
    }
#endif
