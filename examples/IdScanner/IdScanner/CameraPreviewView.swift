import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Remove old preview (simple approach; fine here)
        uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            if let conn = previewLayer.connection, conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }
            uiView.layer.addSublayer(previewLayer)
        }
    }
}
