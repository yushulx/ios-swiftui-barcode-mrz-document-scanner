//
//  VideoBenchmarkView.swift
//  BarcodeBenchmark
//
//  Video benchmark view - compares all 3 SDKs on video frames
//

import SwiftUI
import PhotosUI
import AVKit
import CoreTransferable
import UniformTypeIdentifiers

struct VideoBenchmarkView: View {
    @EnvironmentObject var viewModel: BenchmarkViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var isRunningBenchmark = false
    @State private var statusMessage = ""
    @State private var progress: Double = 0
    @State private var thumbnailImage: UIImage?
    @State private var videoDuration: Double = 0
    @State private var totalFrames = 0
    @State private var importedVideoURL: URL?
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Video Preview
                videoPreviewSection
                
                // Action Buttons
                actionButtons
                
                Spacer()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Video Benchmark")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if isRunningBenchmark {
                loadingOverlay
            }
        }
        .alert("Video Benchmark Error", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onDisappear {
            cleanupImportedVideo()
        }
    }
    
    // MARK: - Video Preview Section
    private var videoPreviewSection: some View {
        VStack {
            if let thumbnail = thumbnailImage {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.sourceFileName ?? "Unknown")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("Duration: \(formatDuration(videoDuration)) | ~\(totalFrames) frames")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(8)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No video selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Select a video to benchmark barcode detection performance across frames")
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
            PhotosPicker(selection: $selectedItem, matching: .videos) {
                HStack {
                    Image(systemName: "film")
                    Text("Select Video")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .onChange(of: selectedItem) { newValue in
                Task {
                    await loadVideo(from: newValue)
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
                .background(thumbnailImage != nil ? Color.green : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(thumbnailImage == nil || isRunningBenchmark)
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Running Benchmark...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.white)
                    .frame(width: 200)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Load Video
    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let importedMovie = try await item.loadTransferable(type: ImportedMovie.self) {
                cleanupImportedVideo()
                let videoURL = importedMovie.url
                let asset = AVAsset(url: videoURL)
                let duration = try await asset.load(.duration)
                
                // Generate thumbnail
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                let cmTime = CMTime(seconds: 0, preferredTimescale: 1)
                let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                
                let durationSeconds = CMTimeGetSeconds(duration)
                let frames = Int(durationSeconds / BenchmarkConfig.frameInterval)
                
                await MainActor.run {
                    viewModel.selectedVideoURL = videoURL
                    viewModel.sourceFileName = videoURL.lastPathComponent
                    thumbnailImage = thumbnail
                    videoDuration = durationSeconds
                    totalFrames = frames
                    importedVideoURL = videoURL
                    errorMessage = nil
                }
            } else {
                await MainActor.run {
                    errorMessage = "The selected video could not be imported."
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load video: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Run Benchmark
    private func runBenchmark() async {
        guard let videoURL = viewModel.selectedVideoURL else { return }
        var didCompleteBenchmark = false
        
        await MainActor.run {
            isRunningBenchmark = true
            viewModel.reset()
            viewModel.selectedVideoURL = videoURL
            progress = 0
            errorMessage = nil
        }
        
        // Extract frames
        await MainActor.run {
            statusMessage = "Extracting frames..."
            progress = 0.1
        }
        
        do {
            let frames = try await VideoFrameExtractor.extractFrames(
                from: videoURL,
                interval: BenchmarkConfig.frameInterval
            )
            guard !frames.isEmpty else {
                throw DetectionError.detectionFailed("No frames could be extracted from the selected video.")
            }
            
            let totalFrameCount = frames.count
            
            await MainActor.run {
                progress = 0.2
            }
            
            // Run Dynamsoft Benchmark
            await runDetectorBenchmark(
                detector: viewModel.dynamsoftDetector,
                engineName: "Dynamsoft",
                frames: frames,
                totalFrames: totalFrameCount,
                startProgress: 0.2,
                endProgress: 0.4
            )
            
            // Run MLKit Benchmark
            await runDetectorBenchmark(
                detector: viewModel.mlkitDetector,
                engineName: "MLKit",
                frames: frames,
                totalFrames: totalFrameCount,
                startProgress: 0.4,
                endProgress: 0.6
            )
            
            // Run Apple Vision Benchmark
            await runDetectorBenchmark(
                detector: viewModel.visionDetector,
                engineName: "Apple Vision",
                frames: frames,
                totalFrames: totalFrameCount,
                startProgress: 0.6,
                endProgress: 0.8
            )
            
            // Run ZXing-CPP Benchmark
            await runDetectorBenchmark(
                detector: viewModel.zxingcppDetector,
                engineName: "ZXing-CPP",
                frames: frames,
                totalFrames: totalFrameCount,
                startProgress: 0.8,
                endProgress: 1.0
            )
            didCompleteBenchmark = true
            
        } catch {
            await MainActor.run {
                errorMessage = "Video processing failed: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isRunningBenchmark = false
            if didCompleteBenchmark {
                viewModel.navigateToResults()
            }
        }
    }
    
    private func runDetectorBenchmark(
        detector: BarcodeDetector,
        engineName: String,
        frames: [UIImage],
        totalFrames: Int,
        startProgress: Double,
        endProgress: Double
    ) async {
        await MainActor.run {
            statusMessage = "Running \(engineName) benchmark..."
        }
        
        var allBarcodes: [BarcodeInfo] = []
        var uniqueBarcodes = Set<String>()
        var totalTimeMs: Int64 = 0
        
        for (index, frame) in frames.enumerated() {
            do {
                let startTime = Date()
                let barcodes = try await detector.detectBarcodes(in: frame)
                let endTime = Date()
                let decodeTime = Int64((endTime.timeIntervalSince(startTime) * 1000))
                totalTimeMs += decodeTime
                
                for barcode in barcodes {
                    let key = "\(barcode.format):\(barcode.text)"
                    if !uniqueBarcodes.contains(key) {
                        uniqueBarcodes.insert(key)
                        var info = BarcodeInfo(
                            format: barcode.format,
                            text: barcode.text,
                            decodeTimeMs: decodeTime,
                            frameIndex: index
                        )
                        info.frameIndex = index
                        allBarcodes.append(info)
                    }
                }
                
                let frameProgress = Double(index + 1) / Double(totalFrames)
                let overallProgress = startProgress + (frameProgress * (endProgress - startProgress))
                
                await MainActor.run {
                    progress = overallProgress
                    statusMessage = "\(engineName): Frame \(index + 1)/\(totalFrames)"
                }
                
            } catch {
                print("\(engineName) detection failed on frame \(index): \(error)")
            }
        }
        
        await MainActor.run {
            var result = BenchmarkResult(engineName: engineName)
            result.framesProcessed = totalFrames
            result.totalTimeMs = totalTimeMs
            result.barcodes = allBarcodes
            
            switch engineName {
            case "Dynamsoft":
                viewModel.dynamsoftResult = result
            case "MLKit":
                viewModel.mlkitResult = result
            case "Apple Vision":
                viewModel.visionResult = result
            case "ZXing-CPP":
                viewModel.zxingcppResult = result
            default:
                break
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }
    
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }
    
    private func cleanupImportedVideo() {
        guard let importedVideoURL else { return }
        try? FileManager.default.removeItem(at: importedVideoURL)
        self.importedVideoURL = nil
    }
}

private struct ImportedMovie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let fileManager = FileManager.default
            let sourceURL = received.file
            let pathExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
            let destinationURL = fileManager.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(pathExtension)
            
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return Self(url: destinationURL)
        }
    }
}

#Preview {
    NavigationStack {
        VideoBenchmarkView()
            .environmentObject(BenchmarkViewModel())
    }
}
