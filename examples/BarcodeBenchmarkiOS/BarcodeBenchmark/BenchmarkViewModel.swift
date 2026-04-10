//
//  BenchmarkViewModel.swift
//  BarcodeBenchmark
//
//  Shared ViewModel for benchmark state management
//

import SwiftUI
import Combine
import Network
import Darwin

@MainActor
class BenchmarkViewModel: ObservableObject {
    
    // MARK: - Navigation
    @Published var navigationPath = NavigationPath()
    
    // MARK: - Settings
    @Published var resolutionIndex: Int = 0 // 0 = 720P, 1 = 1080P
    @Published var benchmarkMode: BenchmarkMode = .camera
    
    // MARK: - Source
    @Published var sourceFileName: String?
    @Published var selectedImage: UIImage?
    @Published var selectedVideoURL: URL?
    
    // MARK: - Web Server
    @Published var webServer: BenchmarkWebServer?
    @Published var isWebServerRunning: Bool = false
    @Published var serverURL: String = ""
    
    // MARK: - Results
    @Published var dynamsoftResult: BenchmarkResult?
    @Published var mlkitResult: BenchmarkResult?
    @Published var visionResult: BenchmarkResult?
    
    // MARK: - Camera Scan Results
    @Published var cameraScanResults: [BarcodeInfo] = []
    
    // MARK: - Progress
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0.0
    @Published var progressStatus: String = ""
    
    // MARK: - Shared Detector Instances
    lazy var dynamsoftDetector = DynamsoftBarcodeDetector()
    lazy var mlkitDetector = MLKitBarcodeDetector()
    lazy var visionDetector = VisionBarcodeDetector()
    
    func reset() {
        dynamsoftResult = nil
        mlkitResult = nil
        visionResult = nil
        cameraScanResults.removeAll()
        sourceFileName = nil
        selectedImage = nil
        selectedVideoURL = nil
        progress = 0.0
        progressStatus = ""
    }
    
    func navigate(to route: Route) {
        navigationPath.append(route)
    }
    
    func navigateToResults() {
        navigationPath.append(Route.results)
    }
    
    func popToRoot() {
        navigationPath.removeLast(navigationPath.count)
    }
    
    func startWebServer() {
        guard webServer == nil else { return }
        
        do {
            let server = try BenchmarkWebServer(port: BenchmarkConfig.serverPort, viewModel: self)
            try server.start()
            webServer = server
            isWebServerRunning = true
            
            if let ip = getLocalIPAddress() {
                serverURL = "http://\(ip):\(BenchmarkConfig.serverPort)"
            }
        } catch {
            print("Failed to start web server: \(error)")
        }
    }
    
    func stopWebServer() {
        webServer?.stop()
        webServer = nil
        isWebServerRunning = false
        serverURL = ""
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "wifi0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address ?? "localhost"
    }
}

// MARK: - Benchmark Mode
enum BenchmarkMode: String {
    case camera = "camera"
    case image = "image"
    case video = "video"
}

// MARK: - Benchmark Result
struct BenchmarkResult: Identifiable {
    let id = UUID()
    let engineName: String
    var totalTimeMs: Int64 = 0
    var framesProcessed: Int = 0
    var barcodes: [BarcodeInfo] = []
    
    init(engineName: String) {
        self.engineName = engineName
    }
    
    var avgTimePerFrame: Double {
        guard framesProcessed > 0 else { return 0 }
        return Double(totalTimeMs) / Double(framesProcessed)
    }
    
    var uniqueBarcodeCount: Int {
        var unique = Set<String>()
        for barcode in barcodes {
            unique.insert("\(barcode.format):\(barcode.text)")
        }
        return unique.count
    }
}

// MARK: - Overlay Box
/// A bounding box drawn over detected barcodes on the live camera feed.
struct OverlayBox {
    /// Normalized rect (0–1) with origin at top-left, for drawing over the camera preview.
    let bounds: CGRect
    /// Short format label shown inside the box.
    let label: String
}

// MARK: - Barcode Info
struct BarcodeInfo: Identifiable {
    let id = UUID()
    let format: String
    let text: String
    let decodeTimeMs: Int64
    var frameIndex: Int?
    /// Normalized bounding rect (0–1, top-left origin) for camera overlay. Nil for image/video mode.
    var normalizedBounds: CGRect?

    init(format: String, text: String, decodeTimeMs: Int64, frameIndex: Int? = nil, normalizedBounds: CGRect? = nil) {
        self.format = format
        self.text = text
        self.decodeTimeMs = decodeTimeMs
        self.frameIndex = frameIndex
        self.normalizedBounds = normalizedBounds
    }
}

// MARK: - Barcode Detection Protocol
protocol BarcodeDetector {
    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo]
    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo]
}

// MARK: - Detection Error
enum DetectionError: Error {
    case invalidImage
    case detectionFailed(String)
    case notInitialized
}
