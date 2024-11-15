//
//  CameraView.swift
//  qrscanner
//
//  Created by xiao on 2022/3/2.
//

import Foundation
import SwiftUI
import DynamsoftCameraEnhancer

struct DynamsoftCameraView: UIViewRepresentable {
    var cameraManager: CameraManager
    func makeUIView(context: Context) -> CameraView {
        let dceView = cameraManager.getCameraView()
        return dceView
    }

    func updateUIView(_ uiView: CameraView, context: Context) {
        
    }
}
