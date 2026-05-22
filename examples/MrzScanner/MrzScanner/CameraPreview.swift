//
//  CameraPreview.swift
//  MrzScanner
//
//  UIViewRepresentable wrapping Dynamsoft CameraView for SwiftUI.
//

import SwiftUI
import DynamsoftCaptureVisionBundle

struct CameraPreview: UIViewRepresentable {
    let cameraView: CameraView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
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

    func updateUIView(_ uiView: UIView, context: Context) {}
}
