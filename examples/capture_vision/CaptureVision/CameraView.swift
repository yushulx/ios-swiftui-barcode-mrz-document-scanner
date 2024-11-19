import AVFoundation
import SwiftUI

#if os(iOS)
    struct CameraView: UIViewControllerRepresentable {
        @Binding var image: ImageType?
        @Binding var shouldCapturePhoto: Bool

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        func makeUIViewController(context: Context) -> CameraViewController {
            let cameraViewController = CameraViewController()
            cameraViewController.onImageCaptured = { capturedImage in
                DispatchQueue.main.async {
                    self.image = capturedImage
                    self.shouldCapturePhoto = false
                }
            }
            context.coordinator.cameraViewController = cameraViewController
            return cameraViewController
        }

        func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
            if shouldCapturePhoto {
                uiViewController.capturePhoto()
            }
        }

        class Coordinator: NSObject {
            var parent: CameraView
            var cameraViewController: CameraViewController?

            init(_ parent: CameraView) {
                self.parent = parent
            }
        }
    }
#elseif os(macOS)
    struct CameraView: NSViewControllerRepresentable {
        @Binding var image: ImageType?
        @Binding var shouldCapturePhoto: Bool

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        func makeNSViewController(context: Context) -> CameraViewController {
            let cameraViewController = CameraViewController()
            cameraViewController.onImageCaptured = { capturedImage in
                DispatchQueue.main.async {
                    self.image = capturedImage
                    self.shouldCapturePhoto = false
                }
            }
            context.coordinator.cameraViewController = cameraViewController
            return cameraViewController
        }

        func updateNSViewController(_ nsViewController: CameraViewController, context: Context) {
            if shouldCapturePhoto {
                nsViewController.capturePhoto()
            }
        }

        class Coordinator: NSObject {
            var parent: CameraView
            var cameraViewController: CameraViewController?

            init(_ parent: CameraView) {
                self.parent = parent
            }
        }
    }
#endif
