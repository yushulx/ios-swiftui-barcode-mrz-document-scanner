//
//  CameraPreviewView.swift
//  BarcodeBenchmark
//
//  Camera preview view using AVFoundation
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @Binding var session: AVCaptureSession?
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let session = session {
            uiView.videoPreviewLayer.session = session
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Camera Manager
class CameraManager: ObservableObject {
    @Published var session: AVCaptureSession?
    @Published var isRunning = false
    @Published var cameraError: Error?
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private var sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    func setupCamera(resolution: CameraResolution, delegate: AVCaptureVideoDataOutputSampleBufferDelegate) throws {
        let session = AVCaptureSession()
        
        // Set resolution
        switch resolution {
        case .hd720:
            session.sessionPreset = .hd1280x720
        case .hd1080:
            session.sessionPreset = .hd1920x1080
        }
        
        // Get back camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCameraAvailable
        }
        
        // Create input
        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        
        if session.canAddInput(videoDeviceInput) {
            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
        }
        
        // Setup output
        videoOutput.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
        
        self.session = session
        self.sampleBufferDelegate = delegate
    }
    
    func startSession() {
        guard let session = session, !session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = session.isRunning
            }
        }
    }
    
    func stopSession() {
        guard let session = session, session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }
    
    func cleanup() {
        stopSession()
        session = nil
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        sampleBufferDelegate = nil
    }
}

enum CameraResolution {
    case hd720
    case hd1080
}

enum CameraError: Error {
    case noCameraAvailable
    case cannotAddInput
    case cannotAddOutput
    case setupFailed
}

// MARK: - Barcode Overlay View
/// Draws colored bounding boxes and format labels over the camera preview.
/// `bufferSize` must match the actual pixel buffer dimensions so the aspect-fill
/// crop applied by `AVCaptureVideoPreviewLayer.resizeAspectFill` is compensated for.
struct BarcodeOverlayView: View {
    let boxes: [OverlayBox]
    let color: Color
    let bufferSize: CGSize   // actual pixel buffer width × height

    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                // Compute the aspect-fill region:
                // The preview layer scales the buffer to fill the view, cropping the excess.
                let displayW: CGFloat
                let displayH: CGFloat
                let offsetX: CGFloat
                let offsetY: CGFloat
                if bufferSize.width > 0, bufferSize.height > 0 {
                    let scale = max(size.width / bufferSize.width, size.height / bufferSize.height)
                    displayW = bufferSize.width * scale
                    displayH = bufferSize.height * scale
                    offsetX  = (displayW - size.width)  / 2
                    offsetY  = (displayH - size.height) / 2
                } else {
                    // Fallback: no buffer size info — map 1:1 to view
                    displayW = size.width
                    displayH = size.height
                    offsetX  = 0
                    offsetY  = 0
                }

                for box in boxes {
                    let rect = CGRect(
                        x: box.bounds.minX * displayW - offsetX,
                        y: box.bounds.minY * displayH - offsetY,
                        width: box.bounds.width * displayW,
                        height: box.bounds.height * displayH
                    )

                    // Stroked bounding rectangle
                    ctx.stroke(
                        Path(roundedRect: rect, cornerRadius: 3),
                        with: .color(color),
                        lineWidth: 2.5
                    )

                    // Label pill above the box
                    let fontSize: CGFloat = 11
                    let pad: CGFloat = 3
                    let charWidth: CGFloat = fontSize * 0.62
                    let labelW = CGFloat(box.label.count) * charWidth + pad * 2
                    let labelH = fontSize + pad * 2
                    let labelX = min(rect.minX, size.width - labelW)
                    let labelY = max(0, rect.minY - labelH - 2)
                    let pillRect = CGRect(x: labelX, y: labelY, width: labelW, height: labelH)

                    ctx.fill(Path(roundedRect: pillRect, cornerRadius: 3), with: .color(color))
                    ctx.draw(
                        Text(box.label)
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundColor(.black),
                        at: CGPoint(x: pillRect.minX + pad, y: pillRect.minY + pad),
                        anchor: .topLeading
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
