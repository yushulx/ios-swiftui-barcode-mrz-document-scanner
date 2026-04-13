//
//  BenchmarkResultView.swift
//  BarcodeBenchmark
//
//  Results view - compares all 3 SDK results side-by-side
//

import SwiftUI

struct BenchmarkResultView: View {
    @EnvironmentObject var viewModel: BenchmarkViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Time Comparison (if enabled)
                if BenchmarkConfig.showBenchmarkTime {
                    timeComparisonSection
                }
                
                // Detection Results
                detectionResultsSection
                
                // Video Stats (if video mode)
                if viewModel.benchmarkMode == .video {
                    videoStatsSection
                }
                
                // Individual Results
                dynamsoftResultsSection
                mlkitResultsSection
                visionResultsSection
                zxingcppResultsSection
                
                // Back Button
                backButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Benchmark Results")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Benchmark Results")
                .font(.title)
                .fontWeight(.bold)
            
            Text("\(viewModel.benchmarkMode == .video ? "Video" : "Image"): \(viewModel.sourceFileName ?? "Unknown")")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Time Comparison Section
    private var timeComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "stopwatch")
                    .foregroundColor(.blue)
                Text("Time Performance")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 16) {
                // Dynamsoft
                timeRow(
                    color: .blue,
                    name: "Dynamsoft",
                    time: viewModel.dynamsoftResult?.totalTimeMs ?? 0,
                    maxTime: maxTime
                )
                
                // MLKit
                timeRow(
                    color: .green,
                    name: "MLKit",
                    time: viewModel.mlkitResult?.totalTimeMs ?? 0,
                    maxTime: maxTime
                )
                
                // Apple Vision
                timeRow(
                    color: .purple,
                    name: "Apple Vision",
                    time: viewModel.visionResult?.totalTimeMs ?? 0,
                    maxTime: maxTime
                )
                
                // ZXing-CPP
                timeRow(
                    color: .orange,
                    name: "ZXing-CPP",
                    time: viewModel.zxingcppResult?.totalTimeMs ?? 0,
                    maxTime: maxTime
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func timeRow(color: Color, name: String, time: Int64, maxTime: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(name)
                    .font(.subheadline)
                
                Spacer()
                
                if viewModel.benchmarkMode == .video {
                    let avg = time > 0 && (viewModel.dynamsoftResult?.framesProcessed ?? 0) > 0
                        ? Double(time) / Double(viewModel.dynamsoftResult?.framesProcessed ?? 1)
                        : 0.0
                    Text(String(format: "%.1f ms/frame (total: %d ms)", avg, time))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                } else {
                    Text("\(time) ms")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                        .frame(height: 8)
                    
                    if maxTime > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: max(4, CGFloat(time) / CGFloat(maxTime) * geometry.size.width), height: 8)
                    }
                }
            }
            .frame(height: 8)
        }
    }
    
    private var maxTime: Int64 {
        let times: [Int64] = [
            viewModel.dynamsoftResult?.totalTimeMs ?? 0,
            viewModel.mlkitResult?.totalTimeMs ?? 0,
            viewModel.visionResult?.totalTimeMs ?? 0,
            viewModel.zxingcppResult?.totalTimeMs ?? 0
        ]
        return times.max() ?? 1
    }
    
    // MARK: - Detection Results Section
    private var detectionResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.blue)
                Text("Detection Results")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            HStack(spacing: 8) {
                // Dynamsoft
                countCard(
                    color: .blue,
                    name: "Dynamsoft",
                    count: viewModel.dynamsoftResult?.barcodes.count ?? 0
                )
                
                // MLKit
                countCard(
                    color: .green,
                    name: "MLKit",
                    count: viewModel.mlkitResult?.barcodes.count ?? 0
                )
                
                // Apple Vision
                countCard(
                    color: .purple,
                    name: "Vision",
                    count: viewModel.visionResult?.barcodes.count ?? 0
                )
                
                // ZXing-CPP
                countCard(
                    color: .orange,
                    name: "ZXing-CPP",
                    count: viewModel.zxingcppResult?.barcodes.count ?? 0
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func countCard(color: Color, name: String, count: Int) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("barcodes")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Video Stats Section
    private var videoStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "film")
                    .foregroundColor(.blue)
                Text("Video Statistics")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Text("Frames processed:")
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(viewModel.dynamsoftResult?.framesProcessed ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Dynamsoft Results Section
    private var dynamsoftResultsSection: some View {
        resultSection(
            color: .blue,
            title: "Dynamsoft Barcodes",
            barcodes: viewModel.dynamsoftResult?.barcodes ?? []
        )
    }
    
    // MARK: - MLKit Results Section
    private var mlkitResultsSection: some View {
        resultSection(
            color: .green,
            title: "MLKit Barcodes",
            barcodes: viewModel.mlkitResult?.barcodes ?? []
        )
    }
    
    // MARK: - Vision Results Section
    private var visionResultsSection: some View {
        resultSection(
            color: .purple,
            title: "Apple Vision Barcodes",
            barcodes: viewModel.visionResult?.barcodes ?? []
        )
    }
    
    // MARK: - ZXing-CPP Results Section
    private var zxingcppResultsSection: some View {
        resultSection(
            color: .orange,
            title: "ZXing-CPP Barcodes",
            barcodes: viewModel.zxingcppResult?.barcodes ?? []
        )
    }
    
    private func resultSection(color: Color, title: String, barcodes: [BarcodeInfo]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 4, height: 20)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
            }
            
            if barcodes.isEmpty {
                Text("No barcodes detected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(spacing: 8) {
                    ForEach(barcodes.prefix(10)) { barcode in
                        BarcodeRowView(barcode: barcode, accentColor: color)
                    }
                    
                    if barcodes.count > 10 {
                        Text("... and \(barcodes.count - 10) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Back Button
    private var backButton: some View {
        Button {
            viewModel.popToRoot()
        } label: {
            Text("Run Another Benchmark")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
        }
    }
}

// MARK: - Barcode Row View
struct BarcodeRowView: View {
    let barcode: BarcodeInfo
    let accentColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(barcode.format)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                
                Spacer()
                
                if let frameIndex = barcode.frameIndex {
                    Text("Frame \(frameIndex + 1)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(truncatedText(barcode.text))
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    private func truncatedText(_ text: String) -> String {
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }
}

#Preview {
    NavigationStack {
        BenchmarkResultView()
            .environmentObject(BenchmarkViewModel())
    }
}
