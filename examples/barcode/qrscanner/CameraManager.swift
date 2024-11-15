//
//  CameraManager.swift
//  qrscanner
//
//  Created by xiao on 2022/3/2.
//

import Foundation
import UIKit
import DynamsoftCameraEnhancer
import DynamsoftCaptureVisionRouter
import DynamsoftBarcodeReader
import DynamsoftCore

class CameraManager: NSObject, ObservableObject, CapturedResultReceiver {
    
    @Published var results = "No QR Code found"
    private var cameraView:CameraView!
    private var dce = CameraEnhancer()
    private var cvr = CaptureVisionRouter()
    
    init(frame: CGRect) {
        super.init()
        setUpCamera(frame: frame)
        setUpDCV()
    }

    func setUpCamera(frame: CGRect) {
        cameraView = .init(frame: frame)
        cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let layer = cameraView.getDrawingLayer(DrawingLayerId.DBR.rawValue)
        layer?.visible = true
        dce.cameraView = cameraView
    }
    
    func setUpDCV() {
        // Set the camera enhancer as the input.
        try! cvr.setInput(dce)
        // Add CapturedResultReceiver to receive the result callback when a video frame is processed.
        cvr.addResultReceiver(self)
    }
    
    func getCameraView() -> CameraView { 
        return cameraView
    }

    func onDecodedBarcodesReceived(_ result: DecodedBarcodesResult) {
        var message = ""
        
        if let items = result.items, items.count > 0 {
            let layer = cameraView.getDrawingLayer(DrawingLayerId.DBR.rawValue)
            layer?.clearDrawingItems()
            for item in items {
                message += String(format:"\nFormat: %@\nText: %@\n", item.formatString, item.text)
                let quadDrawingItem = QuadDrawingItem.init(quadrilateral: item.location)
                let textDrawingItem = TextDrawingItem.init(text: item.text, topLeftPoint: item.location.points[0] as! CGPoint, width: 100, height: 10)
                layer?.addDrawingItems([quadDrawingItem, textDrawingItem])
            }
        }
        
        DispatchQueue.main.async {
            self.results = message
        }
    }
    
    private func showResult(_ title: String, _ message: String?, completion: (() -> Void)? = nil) {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
            }
        }
    
    func viewDidAppear() {
        dce.open()
        cvr.startCapturing(PresetTemplate.readBarcodes.rawValue) { isSuccess, error in
            if (!isSuccess) {
                if let error = error {
                    self.showResult("Error", error.localizedDescription)
                }
            }
        }
    }

    func viewDidDisappear() {
        dce.close()
        cvr.stopCapturing()
    }
}
