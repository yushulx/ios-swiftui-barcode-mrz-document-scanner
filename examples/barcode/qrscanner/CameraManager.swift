//
//  CameraManager.swift
//  qrscanner
//
//  Created by xiao on 2022/3/2.
//

import Foundation
import UIKit
import DynamsoftCaptureVisionBundle

class CameraManager: NSObject, ObservableObject, CapturedResultReceiver {

    // Preset drawing layer for barcode results: 1 = DDN, 2 = DBR, 3 = DLR
    private let barcodeDrawingLayerId: UInt = 2
    private let labelHeight: UInt = 22
    private let labelWidth: UInt = 240
    private var labelDrawingLayerId: UInt = 0

    private var cameraView = CameraView()
    private let dce = CameraEnhancer()
    private let cvr = CaptureVisionRouter()

    override init() {
        super.init()
        setUpDCV()
    }

    func setUpDCV() {
        // Show the barcode drawing layer so decoded results are drawn on the camera view.
        cameraView.getDrawingLayer(barcodeDrawingLayerId)?.visible = true

        // A custom layer that holds one text annotation per decoded barcode.
        let labelStyleId = DrawingStyleManager.createDrawingStyle(
            UIColor.black.withAlphaComponent(0.55),
            strokeWidth: 1,
            fill: UIColor.black.withAlphaComponent(0.55),
            textColor: .white,
            font: .systemFont(ofSize: 12)
        )
        let labelLayer = cameraView.createDrawingLayer()
        labelLayer.visible = true
        labelLayer.setDefaultStyle(labelStyleId)
        labelDrawingLayerId = labelLayer.layerId

        dce.cameraView = cameraView
        // Set the camera enhancer as the input.
        try! cvr.setInput(dce)
        // Add CapturedResultReceiver to receive the result callback when a video frame is processed.
        cvr.addResultReceiver(self)
    }

    func getCameraView() -> CameraView {
        return cameraView
    }

    func onDecodedBarcodesReceived(_ result: DecodedBarcodesResult) {
        guard let items = result.items, items.count > 0,
              let barcodeLayer = cameraView.getDrawingLayer(barcodeDrawingLayerId),
              let labelLayer = cameraView.getDrawingLayer(labelDrawingLayerId) else {
            return
        }

        barcodeLayer.clearDrawingItems()
        labelLayer.clearDrawingItems()

        for item in items {
            barcodeLayer.addDrawingItems([QuadDrawingItem(quadrilateral: item.location)])

            // Place the text annotation above the barcode quad.
            guard let points = item.location.points as? [CGPoint], points.count == 4 else { continue }
            let minX = points.map { $0.x }.min() ?? 0
            let minY = points.map { $0.y }.min() ?? 0
            let gap: CGFloat = 6
            var y = minY - CGFloat(labelHeight) - gap
            if y < 2 {
                y = minY + gap
            }
            let labelItem = TextDrawingItem(
                text: item.text,
                topLeftPoint: CGPoint(x: minX, y: y),
                width: labelWidth,
                height: labelHeight
            )
            labelLayer.addDrawingItems([labelItem])
        }
    }

    func viewDidAppear() {
        dce.open()
        cvr.startCapturing(PresetTemplate.readBarcodes.rawValue) { isSuccess, error in
            if (!isSuccess) {
                if let error = error {
                    print(error.localizedDescription)
                }
            }
        }
    }

    func viewDidDisappear() {
        dce.close()
        cvr.stopCapturing()
    }
}
