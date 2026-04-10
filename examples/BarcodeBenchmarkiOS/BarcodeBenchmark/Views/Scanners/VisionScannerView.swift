//
//  VisionScannerView.swift
//  BarcodeBenchmark
//
//  Live camera scanner using Apple Vision framework
//

import SwiftUI
import AVFoundation
import Combine

struct VisionScannerView: View {
    @EnvironmentObject var viewModel: BenchmarkViewModel
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var scannerState = VisionScannerState()
    @State private var resolution = ""
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: $cameraManager.session)
                .ignoresSafeArea()

            // Bounding-box overlay
            BarcodeOverlayView(boxes: scannerState.overlayBoxes, color: .purple, bufferSize: scannerState.bufferSize)

            // Overlay UI
            VStack {
                // Header
                headerView
                
                Spacer()
                
                // Results Panel
                resultsPanel
            }
            .padding()
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraManager.cleanup()
        }
        .navigationTitle("Apple Vision Scanner")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Resolution: \(resolution)")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    let elapsed = Int(Date().timeIntervalSince(scannerState.scanStartTime))
                    Text("Barcodes: \(scannerState.barcodeCount) | Time: \(elapsed)s")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .foregroundColor(.purple)
                Text("Detected Barcodes")
                    .font(.headline)
                Spacer()
            }
            
            ScrollView {
                if scannerState.scannedBarcodes.isEmpty {
                    Text("No barcodes detected yet...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(scannerState.scannedBarcodes.prefix(5), id: \.self) { barcode in
                            Text(barcode)
                                .font(.caption)
                                .lineLimit(2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .frame(maxHeight: 150)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private func setupCamera() {
        let resolution: CameraResolution = viewModel.resolutionIndex == 0 ? .hd720 : .hd1080
        
        do {
            let delegate = VisionCameraDelegate(viewModel: viewModel, state: scannerState)
            try cameraManager.setupCamera(resolution: resolution, delegate: delegate)
            cameraManager.startSession()
            
            // Update resolution text after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if viewModel.resolutionIndex == 0 {
                    self.resolution = "1280x720"
                } else {
                    self.resolution = "1920x1080"
                }
            }
        } catch {
            print("Camera setup failed: \(error)")
        }
    }
}

// MARK: - Scanner State
class VisionScannerState: ObservableObject {
    @Published var scannedBarcodes: [String] = []
    @Published var barcodeCount = 0
    @Published var overlayBoxes: [OverlayBox] = []
    @Published var bufferSize: CGSize = .zero
    var scanStartTime = Date()
    
    func updateResults(barcodes: [BarcodeInfo]) {
        for barcode in barcodes {
            let displayText = "[\(barcode.format)] \(truncatedText(barcode.text))"
            if !scannedBarcodes.contains(displayText) {
                scannedBarcodes.insert(displayText, at: 0)
                barcodeCount += 1
            }
        }
    }
    
    private func truncatedText(_ text: String) -> String {
        if text.count > 50 {
            return String(text.prefix(50)) + "..."
        }
        return text
    }
}

// MARK: - Camera Delegate
class VisionCameraDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var viewModel: BenchmarkViewModel?
    weak var state: VisionScannerState?
    private var lastProcessingTime: Date = .distantPast
    private let processingInterval: TimeInterval = 0.1
    
    init(viewModel: BenchmarkViewModel, state: VisionScannerState) {
        self.viewModel = viewModel
        self.state = state
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard Date().timeIntervalSince(lastProcessingTime) >= processingInterval else { return }
        lastProcessingTime = Date()
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let bufSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        Task {
            do {
                let barcodes = try await viewModel?.visionDetector.detectBarcodes(in: pixelBuffer) ?? []
                await MainActor.run {
                    state?.bufferSize = bufSize
                    state?.overlayBoxes = barcodes.compactMap { b in
                        guard let bounds = b.normalizedBounds else { return nil }
                        return OverlayBox(bounds: bounds, label: b.format)
                    }
                    if !barcodes.isEmpty {
                        state?.updateResults(barcodes: barcodes)
                    }
                }
            } catch {
                await MainActor.run { state?.overlayBoxes = [] }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VisionScannerView()
            .environmentObject(BenchmarkViewModel())
    }
}
