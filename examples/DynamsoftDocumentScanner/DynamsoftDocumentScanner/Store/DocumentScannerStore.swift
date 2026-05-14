import Foundation
import SwiftUI
import UIKit
import DynamsoftCaptureVisionBundle

@MainActor
final class DocumentScannerStore: ObservableObject {
    @Published var route: ScannerRoute = .scanner
    @Published var pages: [ScannedPage] = []
    @Published var selectedPageIndex: Int = 0
    @Published var retakePageIndex: Int? = nil
    @Published var autoCaptureSettings = AutoCaptureSettings.load() {
        didSet {
            autoCaptureSettings.persist()
        }
    }
    @Published var autoCaptureFlashVisible = false
    @Published var showSettings = false
    @Published var editorTarget: EditorTarget? = nil
    @Published var sharePayload: SharePayload? = nil
    @Published var errorMessage: String? = nil

    private let importRouter = CaptureVisionRouter()

    var currentPage: ScannedPage? {
        guard pages.indices.contains(selectedPageIndex) else { return nil }
        return pages[selectedPageIndex]
    }

    var editorPage: ScannedPage? {
        guard let editorTarget else { return nil }
        return pages.first(where: { $0.id == editorTarget.id })
    }

    func integrateCapturedPage(_ page: ScannedPage, autoCaptured: Bool) {
        if let retakePageIndex, pages.indices.contains(retakePageIndex) {
            pages[retakePageIndex] = page
            selectedPageIndex = retakePageIndex
            self.retakePageIndex = nil
            route = .results
        } else {
            pages.append(page)
            selectedPageIndex = max(0, pages.count - 1)
        }

        if autoCaptured {
            autoCaptureFlashVisible = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                self.autoCaptureFlashVisible = false
            }
        }
    }

    func openResults(from index: Int? = nil) {
        guard !pages.isEmpty else { return }
        if let index, pages.indices.contains(index) {
            selectedPageIndex = index
        } else {
            selectedPageIndex = min(selectedPageIndex, max(0, pages.count - 1))
        }
        route = .results
    }

    func continueScanning() {
        retakePageIndex = nil
        route = .scanner
    }

    func startRetake() {
        guard pages.indices.contains(selectedPageIndex) else { return }
        retakePageIndex = selectedPageIndex
        route = .scanner
    }

    func rotateSelectedPage() {
        guard pages.indices.contains(selectedPageIndex) else { return }
        pages[selectedPageIndex].rotationQuarterTurns = (pages[selectedPageIndex].rotationQuarterTurns + 1) % 4
    }

    func setColorMode(_ mode: DocumentColorMode) {
        guard pages.indices.contains(selectedPageIndex) else { return }
        pages[selectedPageIndex].colorMode = mode
    }

    func removePage(id: UUID) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages.remove(at: index)
        if pages.isEmpty {
            selectedPageIndex = 0
            route = .scanner
            retakePageIndex = nil
            editorTarget = nil
            return
        }
        selectedPageIndex = min(selectedPageIndex, pages.count - 1)
    }

    func movePages(from source: IndexSet, to destination: Int) {
        pages.move(fromOffsets: source, toOffset: destination)
        if let current = currentPage, let newIndex = pages.firstIndex(where: { $0.id == current.id }) {
            selectedPageIndex = newIndex
        }
    }

    func presentEditor() {
        guard let currentPage, currentPage.canEdit else { return }
        editorTarget = EditorTarget(id: currentPage.id)
    }

    func dismissEditor() {
        editorTarget = nil
    }

    func applyEditedQuad(_ quad: Quadrilateral) {
        guard let editorTarget, let index = pages.firstIndex(where: { $0.id == editorTarget.id }) else {
            return
        }
        guard let originalImageData = pages[index].originalImageData else {
            self.editorTarget = nil
            return
        }

        let processor = ImageProcessor()
        do {
            let normalizedImage = try processor.cropAndDeskewImage(originalImageData, quad: quad)
            pages[index].normalizedImageData = normalizedImage
            pages[index].quad = cloneQuadrilateral(quad)
        } catch {
            errorMessage = error.localizedDescription
        }

        self.editorTarget = nil
    }

    func exportPDF() {
        let images = pages.compactMap { $0.renderedImage() }
        guard !images.isEmpty else { return }

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dynamsoft-scan-\(UUID().uuidString)")
            .appendingPathExtension("pdf")

        let firstBounds = CGRect(origin: .zero, size: images[0].size)
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds)

        do {
            try renderer.writePDF(to: exportURL) { context in
                for image in images {
                    let bounds = CGRect(origin: .zero, size: image.size)
                    context.beginPage(withBounds: bounds, pageInfo: [:])
                    image.draw(in: bounds)
                }
            }
            sharePayload = SharePayload(items: [exportURL])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportImages() {
        let baseFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("dynamsoft-images-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: baseFolder, withIntermediateDirectories: true)
            var exportedURLs: [URL] = []

            for (index, page) in pages.enumerated() {
                guard let image = page.renderedImage(), let data = image.jpegData(compressionQuality: 0.94) else {
                    continue
                }
                let url = baseFolder.appendingPathComponent(String(format: "page-%02d.jpg", index + 1))
                try data.write(to: url)
                exportedURLs.append(url)
            }

            guard !exportedURLs.isEmpty else {
                errorMessage = "No pages were available to export."
                return
            }

            sharePayload = SharePayload(items: exportedURLs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importPhotoData(_ data: Data) {
        guard let uiImage = UIImage(data: data)?.normalizedOrientationImage() else {
            errorMessage = "Unable to decode the selected image."
            return
        }

        let originalImageData = try? ImageIO().read(fromMemory: data)
        let capturedResult = importRouter.captureFromImage(uiImage, templateName: detectAndNormalizeTemplateName)

        if let item = capturedResult.processedDocumentResult?.deskewedImageResultItems?.first,
           let normalizedImageData = item.imageData {
            let page = ScannedPage(
                originalImageData: originalImageData,
                normalizedImageData: normalizedImageData,
                quad: cloneQuadrilateral(item.sourceDeskewQuad),
                fallbackImage: nil
            )
            integrateCapturedPage(page, autoCaptured: false)
            return
        }

        let page = ScannedPage(
            originalImageData: nil,
            normalizedImageData: nil,
            quad: nil,
            fallbackImage: uiImage
        )
        integrateCapturedPage(page, autoCaptured: false)
    }
}