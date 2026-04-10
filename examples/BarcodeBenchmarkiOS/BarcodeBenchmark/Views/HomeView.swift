//
//  HomeView.swift
//  BarcodeBenchmark
//
//  Main home view with navigation options
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: BenchmarkViewModel
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView
                
                // Benchmark Input Sources
                inputSourcesSection
                
                // Live Camera Testing
                cameraSection
                
                // Web Server Section
                webServerSection
                
                Spacer(minLength: 40)
                
                // Footer
                Text("Select an input source above to start benchmarking")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Barcode Benchmark")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "barcode.viewfinder")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.blue)
            
            Text("Barcode Benchmark")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Compare Dynamsoft vs MLKit vs Apple Vision")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Input Sources Section
    private var inputSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Benchmark Input Sources")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Image File Card
            NavigationCard(
                icon: "photo.fill",
                iconColor: .white,
                iconBackground: Color.blue,
                title: "Image File",
                subtitle: "Load an image and compare decoding performance"
            ) {
                viewModel.reset()
                viewModel.benchmarkMode = .image
                viewModel.navigate(to: .imageBenchmark)
            }
            
            // Video File Card
            NavigationCard(
                icon: "video.fill",
                iconColor: .white,
                iconBackground: Color.green,
                title: "Video File",
                subtitle: "Process video frames and compare performance"
            ) {
                viewModel.reset()
                viewModel.benchmarkMode = .video
                viewModel.navigate(to: .videoBenchmark)
            }
        }
    }
    
    // MARK: - Camera Section
    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Camera Testing")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Resolution Selector
            resolutionSelector
            
            // Dynamsoft Camera
            NavigationCard(
                icon: "D",
                iconColor: .white,
                iconBackground: Color.blue,
                title: "Dynamsoft Camera",
                subtitle: "Commercial-grade barcode SDK"
            ) {
                viewModel.reset()
                viewModel.benchmarkMode = .camera
                viewModel.navigate(to: .dynamsoftScanner)
            }
            
            // MLKit Camera
            NavigationCard(
                icon: "G",
                iconColor: .white,
                iconBackground: Color.green,
                title: "Google MLKit Camera",
                subtitle: "Free on-device vision API"
            ) {
                viewModel.reset()
                viewModel.benchmarkMode = .camera
                viewModel.navigate(to: .mlkitScanner)
            }
            
            // Apple Vision Camera
            NavigationCard(
                icon: "visionpro",
                iconColor: .white,
                iconBackground: Color.purple,
                title: "Apple Vision Camera",
                subtitle: "Native iOS barcode detection"
            ) {
                viewModel.reset()
                viewModel.benchmarkMode = .camera
                viewModel.navigate(to: .visionScanner)
            }
        }
    }
    
    // MARK: - Resolution Selector
    private var resolutionSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Camera Resolution")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Picker("Resolution", selection: $viewModel.resolutionIndex) {
                Text("720P").tag(0)
                Text("1080P").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Web Server Section
    private var webServerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remote Benchmark (Web Server)")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack {
                        Image(systemName: "globe")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading) {
                            Text("Web Server")
                                .font(.headline)
                            Text("Upload files from desktop browser")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.isWebServerRunning)
                        .onChange(of: viewModel.isWebServerRunning) { newValue in
                            if newValue {
                                viewModel.startWebServer()
                            } else {
                                viewModel.stopWebServer()
                            }
                        }
                }
                
                if viewModel.isWebServerRunning && !viewModel.serverURL.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server Running")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        Text("Open in desktop browser:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(viewModel.serverURL)
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = viewModel.serverURL
                                } label: {
                                    Label("Copy URL", systemImage: "doc.on.doc")
                                }
                            }
                        
                        Text("💡 Make sure your PC is on the same network")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Navigation Card
struct NavigationCard: View {
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    init(
        icon: String,
        iconColor: Color,
        iconBackground: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackground = iconBackground
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 48, height: 48)
                    
                    if icon.count == 1 {
                        Text(icon)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(iconColor)
                    } else {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(iconColor)
                    }
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(BenchmarkViewModel())
    }
}
