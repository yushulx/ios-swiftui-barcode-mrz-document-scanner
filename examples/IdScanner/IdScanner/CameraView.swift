import SwiftUI
import AVFoundation
import Vision

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isProcessing = false

    let onImageCaptured: (UIImage, [String]) -> Void

    var body: some View {
        ZStack {
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()

            // Debug heads-up
            VStack(alignment: .leading, spacing: 6) {
                Text("Frame Debug").font(.caption).fontWeight(.bold)
                Text("Size: \(Int(cameraManager.currentFrameSize.width))×\(Int(cameraManager.currentFrameSize.height))").font(.caption)
                Text(cameraManager.frameOrientation).font(.caption)
                if let thumb = cameraManager.currentFrameThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .border(.red, width: 2)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(8)
            .background(Color.black.opacity(0.35))
            .cornerRadius(8)
            .padding(.top, 40)
            .padding(.leading, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Vision overlays aligned via previewLayer conversions
            OverlayView(
                faces: cameraManager.detectedFaces,
                rectangles: cameraManager.detectedRectangles,
                previewLayer: cameraManager.previewLayer
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                Button(action: captureImage) {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 72, height: 72)
                        Circle().stroke(Color.black, lineWidth: 2).frame(width: 72, height: 72)
                        if isProcessing {
                            ProgressView().tint(.black)
                        }
                    }
                }
                .disabled(isProcessing)
                .padding(.bottom, 50)
            }
        }
        .onAppear { cameraManager.startSession() }
        .onDisappear { cameraManager.stopSession() }
    }

    private func captureImage() {
        isProcessing = true
        cameraManager.capturePhoto { captured in
            guard let image = captured else {
                isProcessing = false
                return
            }
            // Process on background thread if heavy
            DispatchQueue.global(qos: .userInitiated).async {
                let rectified = rectifyImage(image)
                let ocr = performOCR(on: rectified)
                DispatchQueue.main.async {
                    onImageCaptured(rectified, ocr)
                    isProcessing = false
                }
            }
        }
    }

    private func rectifyImage(_ image: UIImage) -> UIImage {
        guard let best = cameraManager.detectedRectangles.first else { return image }
        return ImageRectifier.rectify(image: image, rectangle: best) ?? image
    }

    private func performOCR(on image: UIImage) -> [String] {
        OCRService.extractText(from: image)
    }
}
