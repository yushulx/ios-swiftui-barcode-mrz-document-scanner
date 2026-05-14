import SwiftUI
import UIKit
import DynamsoftCaptureVisionBundle

struct CameraScannerView: UIViewControllerRepresentable {
    @EnvironmentObject private var store: DocumentScannerStore

    let manualCaptureToken: Int
    let settings: AutoCaptureSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, settings: settings)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        context.coordinator.makeViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.update(settings: settings, manualCaptureToken: manualCaptureToken)
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, CapturedResultReceiver {
        private struct CaptureCandidate {
            let originalImageData: ImageData?
            let normalizedImageData: ImageData
            let quad: Quadrilateral?
            let crossVerified: Bool
        }

        private unowned let store: DocumentScannerStore
        private let router = CaptureVisionRouter()
        private let stabilizer: QuadStabilizer

        private var cameraEnhancer: CameraEnhancer?
        private var latestCandidate: CaptureCandidate?
        private var cooldown = false
        private var awaitingManualCapture = false
        private var lastManualCaptureToken = 0
        private var fallbackWorkItem: DispatchWorkItem?

        init(store: DocumentScannerStore, settings: AutoCaptureSettings) {
            self.store = store
            self.stabilizer = QuadStabilizer(settings: settings)
            super.init()
        }

        func makeViewController() -> UIViewController {
            let controller = UIViewController()
            controller.view.backgroundColor = .black

            let cameraView = CameraView(frame: .zero)
            cameraView.translatesAutoresizingMaskIntoConstraints = false
            cameraView.scanRegionMaskVisible = false
            cameraView.torchButtonVisible = false
            controller.view.addSubview(cameraView)

            NSLayoutConstraint.activate([
                cameraView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
                cameraView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
                cameraView.topAnchor.constraint(equalTo: controller.view.topAnchor),
                cameraView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
            ])

            cameraEnhancer = CameraEnhancer(view: cameraView)

            if let cameraEnhancer {
                cameraEnhancer.setResolution(.resolution1080P)
                try? router.setInput(cameraEnhancer)
            }

            configureTemplate()
            router.addResultReceiver(self)
            start()

            return controller
        }

        func update(settings: AutoCaptureSettings, manualCaptureToken: Int) {
            stabilizer.settings = settings
            if lastManualCaptureToken != manualCaptureToken {
                lastManualCaptureToken = manualCaptureToken
                requestManualCapture()
            }
        }

        func start() {
            cameraEnhancer?.open()
            router.startCapturing(detectAndNormalizeTemplateName) { [weak self] isSuccess, error in
                guard let self, !isSuccess else { return }
                Task { @MainActor in
                    self.store.errorMessage = error?.localizedDescription ?? "Failed to start capturing."
                }
            }
        }

        func stop() {
            fallbackWorkItem?.cancel()
            fallbackWorkItem = nil
            router.stopCapturing()
            router.removeAllResultReceivers()
            cameraEnhancer?.close()
        }

        private func configureTemplate() {
            guard let settings = try? router.getSimplifiedSettings(detectAndNormalizeTemplateName) else {
                return
            }

            settings.outputOriginalImage = true
            settings.minImageCaptureInterval = 0
            settings.timeout = 3000
            settings.maxParallelTasks = 1
            settings.documentSettings?.expectedDocumentsCount = 1
            _ = try? router.updateSettings(detectAndNormalizeTemplateName, settings: settings)
        }

        private func requestManualCapture() {
            guard !cooldown else { return }

            fallbackWorkItem?.cancel()
            latestCandidate = nil
            awaitingManualCapture = true

            let workItem = DispatchWorkItem { [weak self] in
                self?.captureFallbackFrameIfNeeded()
            }
            fallbackWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }

        private func captureFallbackFrameIfNeeded() {
            guard awaitingManualCapture, !cooldown else { return }
            awaitingManualCapture = false

            guard let frame = cameraEnhancer?.getImage() else { return }

            let page = ScannedPage(
                originalImageData: frame,
                normalizedImageData: frame,
                quad: nil,
                fallbackImage: nil
            )
            commit(page: page, autoCaptured: false)
        }

        private func commit(_ candidate: CaptureCandidate, autoCaptured: Bool) {
            let page = ScannedPage(
                originalImageData: candidate.originalImageData,
                normalizedImageData: candidate.normalizedImageData,
                quad: candidate.quad,
                fallbackImage: nil
            )
            commit(page: page, autoCaptured: autoCaptured)
        }

        private func commit(page: ScannedPage, autoCaptured: Bool) {
            guard !cooldown else { return }
            cooldown = true
            stabilizer.reset()

            Task { @MainActor in
                store.integrateCapturedPage(page, autoCaptured: autoCaptured)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.cooldown = false
            }
        }

        func onProcessedDocumentResultReceived(_ result: ProcessedDocumentResult) {
            guard let item = result.deskewedImageResultItems?.first,
                  let normalizedImageData = item.imageData else {
                return
            }

            let originalImageData = router.getIntermediateResultManager().getOriginalImage(result.originalImageHashId)
            let candidate = CaptureCandidate(
                originalImageData: originalImageData,
                normalizedImageData: normalizedImageData,
                quad: cloneQuadrilateral(item.sourceDeskewQuad),
                crossVerified: item.crossVerificationStatus.rawValue == 1
            )

            latestCandidate = candidate

            if awaitingManualCapture {
                awaitingManualCapture = false
                fallbackWorkItem?.cancel()
                fallbackWorkItem = nil
                commit(candidate, autoCaptured: false)
                return
            }

            guard candidate.crossVerified, let quad = candidate.quad else { return }
            if stabilizer.feed(quad) {
                commit(candidate, autoCaptured: true)
            }
        }
    }
}