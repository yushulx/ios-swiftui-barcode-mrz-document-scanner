//
//  ContentView.swift
//  MrzScanner
//
//  ID Document Scanner UI with camera preview, overlay controls,
//  progress indicator, and capture button.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var controller = ScannerController()

    var body: some View {
        ZStack {
            // Camera preview (fills entire screen)
            CameraPreview(cameraView: controller.cameraView)
                .ignoresSafeArea()

            // Overlay controls
            VStack {
                // Status text
                HStack {
                    if !controller.statusText.isEmpty {
                        Text(controller.statusText)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // MRZ result text overlay
                if !controller.mrzResultText.isEmpty {
                    Text(controller.mrzResultText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                // Bottom controls
                HStack {
                    Spacer()

                    // Capture button
                    Button(action: {
                        controller.onCapture()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 68, height: 68)
                            Circle()
                                .fill(controller.isCapturing ? Color.gray : Color.white)
                                .frame(width: 58, height: 58)
                            if controller.isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                        }
                    }
                    .disabled(controller.isCapturing || controller.pendingLabelMap == nil)

                    Spacer()
                }
                .padding(.bottom, 32)
            }
            .padding(.top, 40)

            // Error message overlay
            if let error = controller.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $controller.showResult) {
            ScanResultView(
                labelMap: controller.pendingLabelMap ?? [:],
                portraitImage: controller.pendingPortraitImage
            )
        }
        .onAppear {
            controller.setup()
            controller.startScanning()
        }
        .onDisappear {
            controller.stopScanning()
        }
    }
}

#Preview {
    NavigationStack {
        ContentView()
    }
}
