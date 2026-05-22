//
//  ScannerController.swift
//  MrzScanner
//
//  Core scanning controller mirroring Android MainActivity logic.
//  Manages CameraEnhancer, CaptureVisionRouter, intermediate results,
//  portrait detection, and MRZ recognition pipeline.
//

import SwiftUI
import UIKit
import Combine
import DynamsoftCaptureVisionBundle

@MainActor
class ScannerController: NSObject, ObservableObject,
    CapturedResultReceiver, IntermediateResultReceiver
{
    // MARK: - Published UI state (mirrors Android tvStatus, tvResult, progress, etc.)
    @Published var statusText: String = ""
    @Published var mrzResultText: String = ""
    @Published var isCapturing: Bool = true
    @Published var pendingLabelMap: [String: String]?
    @Published var pendingPortraitImage: UIImage?
    @Published var showResult: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dynamsoft pipeline components
    let cameraView = CameraView()
    private let dce = CameraEnhancer()
    private let cvr = CaptureVisionRouter()
    private let idProcessor = IdentityProcessor()

    // MARK: - Overlay drawing layer IDs
    private var portraitLayerId: UInt = 100

    // MARK: - Intermediate result units (mirrors Android mScaledColourImageUnit, etc.)
    private var scaledColourImageUnit: ScaledColourImageUnit?
    private var localizedTextLinesUnit: LocalizedTextLinesUnit?
    private var recognizedTextLinesUnit: RecognizedTextLinesUnit?
    private var detectedQuadsUnit: DetectedQuadsUnit?
    private var deskewedImageUnit: DeskewedImageUnit?

    // MARK: - Setup (mirrors Android onCreate)
    func setup() {
        // License (same key as Android MrzParser)
        MrzParser.initLicense()

        // Camera setup
        dce.cameraView = cameraView
        // Enable frame filter for better stability (mirrors Android EF_FRAME_FILTER)
        dce.enableEnhancedFeatures(.frameFilter)

        // Result cross-verification filter (mirrors iOS MRZScannerViewController setupDCV)
        let filter = MultiFrameResultCrossFilter()
        filter.enableResultCrossVerification([.textLine, .detectedQuad], isEnabled: true)
        let criteria = CrossVerificationCriteria()
        criteria.frameWindow = 5
        criteria.minConsistentFrames = 2
        filter.setResultCrossVerificationCriteria(criteria, resultItemTypes: .detectedQuad)
        cvr.addResultFilter(filter)

        // Init settings from template file (mrz-mobile.json from mrz-scanner-mobile/ios)
        if let templatePath = Bundle.main.path(forResource: "mrz-mobile", ofType: "json") {
            try? cvr.initSettingsFromFile(templatePath)
        }

        // Set camera as input
        try? cvr.setInput(dce)

        // Configure "ReadPassportAndId" template (mirrors Android getSimplifiedSettings)
        if let settings = try? cvr.getSimplifiedSettings("ReadPassportAndId") {
            settings.documentSettings?.minQuadrilateralAreaRatio = 2
            try? cvr.updateSettings("ReadPassportAndId", settings: settings)
        }

        // Register receivers
        cvr.getIntermediateResultManager().addResultReceiver(self)
        cvr.addResultReceiver(self)

        // Configure drawing layers for overlays (document quad, MRZ zone, portrait zone)
        configureDrawingLayers()
    }

    /// Set up drawing layers: DDN for document quad, DLR for MRZ text lines, custom for portrait
    private func configureDrawingLayers() {
        // Make preset layers visible so SDK auto-draws detected quads and text lines
        cameraView.getDrawingLayer(1)?.visible = true   // DDN layer (document quad)
        cameraView.getDrawingLayer(3)?.visible = true   // DLR layer (MRZ text lines)

        // Create a custom portrait layer with cyan stroke style
        let portraitStyleId = DrawingStyleManager.createDrawingStyle(
            .cyan, strokeWidth: 3,
            fill: UIColor.cyan.withAlphaComponent(0.1),
            textColor: .white, font: .systemFont(ofSize: 12)
        )
        let portraitLayer = cameraView.createDrawingLayer()
        portraitLayer.visible = true
        portraitLayer.setDefaultStyle(portraitStyleId)
        portraitLayerId = portraitLayer.layerId
    }

    // MARK: - Lifecycle (mirrors Android onResume / onPause)
    func startScanning() {
        mrzResultText = ""
        pendingLabelMap = nil
        pendingPortraitImage = nil
        statusText = ""
        errorMessage = nil
        clearUnits()
        clearAllOverlays()
        isCapturing = true

        dce.open()
        cvr.startCapturing("ReadPassportAndId") { [weak self] isSuccess, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if isSuccess {
                    self.statusText = "Ready"
                } else if let error = error {
                    self.errorMessage = "Error: \((error as NSError).code) \(error.localizedDescription)"
                }
            }
        }
    }

    func stopScanning() {
        dce.close()
        cvr.stopCapturing()
        clearAllOverlays()
    }

    func onCapture() {
        guard pendingLabelMap != nil else { return }
        showResult = true
    }

    // MARK: - Private helpers

    private func clearUnits() {
        scaledColourImageUnit = nil
        localizedTextLinesUnit = nil
        recognizedTextLinesUnit = nil
        detectedQuadsUnit = nil
        deskewedImageUnit = nil
    }

    /// Clear all drawing overlays (document quad, MRZ zone, portrait zone)
    private func clearAllOverlays() {
        cameraView.getDrawingLayer(1)?.clearDrawingItems()
        cameraView.getDrawingLayer(3)?.clearDrawingItems()
        cameraView.getDrawingLayer(portraitLayerId)?.clearDrawingItems()
    }

    /// Draw document quad and portrait zone overlays on the camera view
    private func drawOverlays(result: CapturedResult, portraitZone: Quadrilateral?) {
        // Document quad overlay on DDN layer
        let ddnLayer = cameraView.getDrawingLayer(1)
        if let quadItem = result.processedDocumentResult?.detectedQuadResultItems?.first {
            ddnLayer?.clearDrawingItems()
            let quadDrawingItem = QuadDrawingItem(quadrilateral: quadItem.location)
            ddnLayer?.addDrawingItems([quadDrawingItem])
        } else {
            ddnLayer?.clearDrawingItems()
        }

        // Portrait zone overlay on custom layer (cyan) — clear when no portrait detected
        let portraitLayer = cameraView.getDrawingLayer(portraitLayerId)
        if let pz = portraitZone {
            portraitLayer?.clearDrawingItems()
            let portraitItem = QuadDrawingItem(quadrilateral: pz)
            portraitLayer?.addDrawingItems([portraitItem])
        } else {
            portraitLayer?.clearDrawingItems()
        }
    }

    /// Find portrait zone with high confidence (mirrors Android portrait detection logic)
    private func findPortraitZone() -> Quadrilateral? {
        guard let scaledUnit = scaledColourImageUnit,
              let localizedUnit = localizedTextLinesUnit,
              let textLinesUnit = recognizedTextLinesUnit,
              let quadsUnit = detectedQuadsUnit,
              quadsUnit.getCount() > 0,
              let imageUnit = deskewedImageUnit,
              let elements = localizedUnit.getAuxiliaryRegionElements() else {
            return nil
        }

        // Check for high-confidence PortraitZone auxiliary region (mirrors Android)
        var hasHighConfidence = false
        for element in elements {
            if element.getName() == "PortraitZone" && element.getConfidence() > 60 {
                hasHighConfidence = true
                break
            }
        }
        guard hasHighConfidence else { return nil }

        return idProcessor.findPortraitZone(
            scaledUnit,
            localizedTextLinesUnit: localizedUnit,
            recognizedTextLinesUnit: textLinesUnit,
            detectedQuadsUnit: quadsUnit,
            deskewedImageUnit: imageUnit
        )
    }
}

// MARK: - CapturedResultReceiver (mirrors Android CapturedResultReceiver)
extension ScannerController {

    public func onCapturedResultReceived(_ result: CapturedResult) {
        // 1. Parse MRZ (mirrors Android: ParsedResult -> MrzParser.parse)
        guard let parsedItem = result.parsedResult?.items?.first else { return }
        let map = MrzParser.parse(parsedItem)
        guard !map.isEmpty else { return }

        // 2. Get document quad for portrait validation
        let quadItem = result.processedDocumentResult?.detectedQuadResultItems?.first

        // 3. Portrait detection (mirrors Android portrait zone detection)
        var portraitZone = findPortraitZone()

        // 4. Validate portrait is inside document and proportionally reasonable
        if let pz = portraitZone, let quad = quadItem {
            let docRegion = quad.location
            let allInside = pz.points.allSatisfy { docRegion.contains($0.cgPointValue) }
            let areaRatioOk = docRegion.area / pz.area >= 3
            if !allInside || !areaRatioOk {
                portraitZone = nil
            }
        }

        // 5. Crop portrait from original image using ImageProcessor
        var portrait: UIImage?
        if portraitZone != nil {
            if let imageData = cvr.getIntermediateResultManager().getOriginalImage(result.originalImageHashId),
               let pz = portraitZone {
                portrait = try? ImageProcessor().cropAndDeskewImage(imageData, quad: pz).toUIImage()
            }
        }

        // 6. Draw overlays: document quad + portrait zone
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.drawOverlays(result: result, portraitZone: portraitZone)
        }

        // 7. Store pending data on main thread (mirrors Android runOnUiThread)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.pendingLabelMap = map
            self.pendingPortraitImage = portrait
            self.isCapturing = false
            self.statusText = portrait != nil ? "Ready" : "MRZ ready"
        }
    }

    public func onRecognizedTextLinesReceived(_ result: RecognizedTextLinesResult) {
        DispatchQueue.main.async {
            guard let items = result.items, !items.isEmpty else {
                self.mrzResultText = ""
                self.cameraView.getDrawingLayer(3)?.clearDrawingItems()
                return
            }
            let text = items.map { $0.text }.joined(separator: "\n")
            self.mrzResultText = text

            // Draw MRZ text line quads on DLR layer
            let dlrLayer = self.cameraView.getDrawingLayer(3)
            dlrLayer?.clearDrawingItems()
            let mrzItems: [DrawingItem] = items.map {
                QuadDrawingItem(quadrilateral: $0.location)
            }
            if !mrzItems.isEmpty {
                dlrLayer?.addDrawingItems(mrzItems)
            }
        }
    }
}

// MARK: - IntermediateResultReceiver (mirrors Android IntermediateResultReceiver)
extension ScannerController {

    public func onScaledColourImageUnitReceived(_ unit: ScaledColourImageUnit, info: IntermediateResultExtraInfo) {
        DispatchQueue.main.async { self.scaledColourImageUnit = unit }
    }

    public func onLocalizedTextLinesReceived(_ unit: LocalizedTextLinesUnit, info: IntermediateResultExtraInfo) {
        DispatchQueue.main.async { self.localizedTextLinesUnit = unit }
    }

    public func onRecognizedTextLinesReceived(_ unit: RecognizedTextLinesUnit, info: IntermediateResultExtraInfo) {
        DispatchQueue.main.async { self.recognizedTextLinesUnit = unit }
    }

    public func onDetectedQuadsReceived(_ unit: DetectedQuadsUnit, info: IntermediateResultExtraInfo) {
        DispatchQueue.main.async {
            self.detectedQuadsUnit = unit
            // Clear document quad and portrait overlays when no quads detected
            if unit.getCount() == 0 {
                self.cameraView.getDrawingLayer(1)?.clearDrawingItems()
                self.cameraView.getDrawingLayer(self.portraitLayerId)?.clearDrawingItems()
            }
        }
    }

    public func onDeskewedImageReceived(_ unit: DeskewedImageUnit, info: IntermediateResultExtraInfo) {
        DispatchQueue.main.async { self.deskewedImageUnit = unit }
    }
}
