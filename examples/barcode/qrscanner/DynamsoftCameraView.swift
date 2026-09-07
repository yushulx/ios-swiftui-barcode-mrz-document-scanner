//
//  DynamsoftCameraView.swift
//  qrscanner
//
//  Created by xiao on 2022/3/2.
//

import Foundation
import SwiftUI
import DynamsoftCaptureVisionBundle

struct DynamsoftCameraView: UIViewRepresentable {
    var cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black

        let cameraView = cameraManager.getCameraView()
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: container.topAnchor),
            cameraView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            cameraView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {

    }
}
