//
//  ImageBenchmarkView.swift
//  BarcodeBenchmark
//
//  Image benchmark view - compares all 3 SDKs on a single image
//

import SwiftUI
import PhotosUI

struct ImageBenchmarkView: View {
    @EnvironmentObject var viewModel: BenchmarkViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var isRunningBenchmark = false
    @State private var statusMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Image Preview
                imagePreviewSection
                
                // Action Buttons
                actionButtons
                
                Spacer()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Image Benchmark")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if isRunningBenchmark {
                loadingOverlay
            }
        }
    }
    
    // MARK: - Image Preview Section
    private var imagePreviewSection: some View {
        VStack {
            if let image = viewModel.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 2)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No image selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Select an image to benchmark barcode detection performance")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 250)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Select Image")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .onChange(of: selectedItem) { newValue in
                Task {
                    await loadImage(from: newValue)
                }
            }
            
            Button {
                Task {
                    await runBenchmark()
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Run Benchmark")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.selectedImage != nil ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.selectedImage == nil || isRunningBenchmark)
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Running Benchmark...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Load Image
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    viewModel.selectedImage = image
                    viewModel.sourceFileName = item.itemIdentifier
                }
            }
        } catch {
            print("Failed to load image: \(error)")
        }
    }
    
    // MARK: - Run Benchmark
    private func runBenchmark() async {
        guard let image = viewModel.selectedImage else { return }
        
        await MainActor.run {
            isRunningBenchmark = true
            viewModel.reset()
        }
        
        // Run Dynamsoft Benchmark
        await MainActor.run {
            statusMessage = "Processing with Dynamsoft..."
        }
        do {
            let startTime = Date()
            let barcodes = try await viewModel.dynamsoftDetector.detectBarcodes(in: image)
            let endTime = Date()
            let timeMs = Int64((endTime.timeIntervalSince(startTime) * 1000))
            
            await MainActor.run {
                var result = BenchmarkResult(engineName: "Dynamsoft")
                result.framesProcessed = 1
                result.totalTimeMs = timeMs
                result.barcodes = barcodes.map { BarcodeInfo(format: $0.format, text: $0.text, decodeTimeMs: timeMs) }
                viewModel.dynamsoftResult = result
            }
        } catch {
            print("Dynamsoft detection failed: \(error)")
        }
        
        // Run MLKit Benchmark
        await MainActor.run {
            statusMessage = "Processing with MLKit..."
        }
        do {
            let startTime = Date()
            let barcodes = try await viewModel.mlkitDetector.detectBarcodes(in: image)
            let endTime = Date()
            let timeMs = Int64((endTime.timeIntervalSince(startTime) * 1000))
            
            await MainActor.run {
                var result = BenchmarkResult(engineName: "MLKit")
                result.framesProcessed = 1
                result.totalTimeMs = timeMs
                result.barcodes = barcodes.map { BarcodeInfo(format: $0.format, text: $0.text, decodeTimeMs: timeMs) }
                viewModel.mlkitResult = result
            }
        } catch {
            print("MLKit detection failed: \(error)")
        }
        
        // Run Apple Vision Benchmark
        await MainActor.run {
            statusMessage = "Processing with Apple Vision..."
        }
        do {
            let startTime = Date()
            let barcodes = try await viewModel.visionDetector.detectBarcodes(in: image)
            let endTime = Date()
            let timeMs = Int64((endTime.timeIntervalSince(startTime) * 1000))
            
            await MainActor.run {
                var result = BenchmarkResult(engineName: "Apple Vision")
                result.framesProcessed = 1
                result.totalTimeMs = timeMs
                result.barcodes = barcodes.map { BarcodeInfo(format: $0.format, text: $0.text, decodeTimeMs: timeMs) }
                viewModel.visionResult = result
            }
        } catch {
            print("Vision detection failed: \(error)")
        }
        
        // Run ZXing-CPP Benchmark
        await MainActor.run {
            statusMessage = "Processing with ZXing-CPP..."
        }
        do {
            let startTime = Date()
            let barcodes = try await viewModel.zxingcppDetector.detectBarcodes(in: image)
            let endTime = Date()
            let timeMs = Int64((endTime.timeIntervalSince(startTime) * 1000))
            
            await MainActor.run {
                var result = BenchmarkResult(engineName: "ZXing-CPP")
                result.framesProcessed = 1
                result.totalTimeMs = timeMs
                result.barcodes = barcodes.map { BarcodeInfo(format: $0.format, text: $0.text, decodeTimeMs: timeMs) }
                viewModel.zxingcppResult = result
            }
        } catch {
            print("ZXing-CPP detection failed: \(error)")
        }
        
        await MainActor.run {
            isRunningBenchmark = false
            viewModel.navigateToResults()
        }
    }
}

#Preview {
    NavigationStack {
        ImageBenchmarkView()
            .environmentObject(BenchmarkViewModel())
    }
}
