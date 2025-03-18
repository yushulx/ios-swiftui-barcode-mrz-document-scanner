#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif
import PDFKit
import SwiftUI

class ScannerViewModel: ObservableObject {
    @Published var rawScanners: [[String: Any]] = []
    @Published var selectedScannerName: String?
    @Published var scannedImages: [PlatformImage] = []
    
    private let scannerController = ScannerController()
    private let apiURL = "http://192.168.8.72:18622"
    private let licenseKey = "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ=="
    private let scanConfig: [String: Any] = [
        "IfShowUI": false,
        "PixelType": 2,
        "Resolution": 200,
        "IfFeederEnabled": false,
        "IfDuplexEnabled": false
    ]
    
    func fetchScanners() async {
        let jsonArray = await scannerController.getDevices(
            host: apiURL,
            scannerType: ScannerType.TWAINX64SCANNER | ScannerType.ESCLSCANNER
        )
        
        await MainActor.run {
            rawScanners = jsonArray
            selectedScannerName = jsonArray.first?["name"] as? String
        }
    }
    
    func scanDocument() async {
        guard let scanner = rawScanners.first(where: { $0["name"] as? String == selectedScannerName }),
              let device = scanner["device"]
        else { return }
        
        let parameters: [String: Any] = [
            "license": licenseKey,
            "device": device,
            "config": scanConfig
        ]
        
        let result = await scannerController.scanDocument(
            host: apiURL,
            parameters: parameters
        )
        
        if let jobId = result[ScannerController.SCAN_SUCCESS] {
            await fetchImages(jobId: jobId)
        }
    }
    
    private func fetchImages(jobId: String) async {
        let streams = await scannerController.getImageStreams(host: apiURL, jobId: jobId)
        
        for bytes in streams {
            let data = Data(bytes: bytes, count: bytes.count)
            await MainActor.run {
                #if os(macOS)
                guard let image = NSImage(data: data) else { return }
                #else
                guard let image = UIImage(data: data) else { return }
                #endif
                scannedImages.append(image)
            }
        }
    }
    
    func saveImagesToPDF() {
        #if os(macOS)
        let pdfDocument = PDFDocument()
        for (index, image) in scannedImages.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "ScannedDocument.pdf"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            pdfDocument.write(to: url)
        }
        #else
        guard let pdfData = createPDFData() else { return }
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ScannedDocument.pdf")
        
        do {
            try pdfData.write(to: tempURL)
            let controller = UIDocumentPickerViewController(forExporting: [tempURL])
            if let windowScene = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .first as? UIWindowScene {
                
                windowScene.windows.first?.rootViewController?.present(controller, animated: true)
            }
        } catch {
            print("Save failed: \(error.localizedDescription)")
        }
        #endif
    }
    
    #if os(iOS)
    private func createPDFData() -> Data? {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            for image in scannedImages {
                context.beginPage()
                let imageRect = imageRectForPage(pageRect, image: image)
                image.draw(in: imageRect)
            }
        }
    }
    
    private func imageRectForPage(_ pageRect: CGRect, image: PlatformImage) -> CGRect {
        let maxSize = CGSize(width: pageRect.width - 40, height: pageRect.height - 40)
        let aspectRatio = min(maxSize.width/image.size.width, maxSize.height/image.size.height)
        let size = CGSize(width: image.size.width * aspectRatio, height: image.size.height * aspectRatio)
        return CGRect(x: (pageRect.width - size.width)/2, y: (pageRect.height - size.height)/2, width: size.width, height: size.height)
    }
    #endif
}

struct ContentView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            Picker("Select Scanner", selection: $viewModel.selectedScannerName) {
                ForEach(viewModel.rawScanners.indices, id: \.self) { index in
                    if let name = viewModel.rawScanners[index]["name"] as? String {
                        Text(name).tag(name as String?)
                    }
                }
            }
            .pickerStyle(.menu)
            .padding()
            
            HStack {
                Button("Fetch Scanners") {
                    Task { await viewModel.fetchScanners() }
                }
                Button("Scan Document") {
                    Task { await viewModel.scanDocument() }
                }
                .disabled(viewModel.selectedScannerName == nil)
            }
            .padding()
            
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(viewModel.scannedImages.enumerated()), id: \.offset) {
                        index, image in
                        let image = viewModel.scannedImages[index]
                        #if os(macOS)
                        Image(nsImage: image).resizable()
                            .scaledToFit()
                            .frame(height: 400)
                            .id(index)
                        #else
                        Image(uiImage: image).resizable()
                            .scaledToFit()
                            .frame(height: 400)
                            .id(index)
                        #endif
                    }
                }
                .onChange(of: viewModel.scannedImages.count) {
                    withAnimation {
                        proxy.scrollTo(viewModel.scannedImages.count - 1, anchor: .bottom)
                    }
                }
            }
            
            Button("Save to PDF") {
                viewModel.saveImagesToPDF()
            }
            .padding()
        }
        .onAppear {
            Task { await viewModel.fetchScanners() }
        }
        .alert("Scanner Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .frame(width: 500, height: 600)
    }
}

#Preview {
    ContentView()
}
