import DynamsoftBarcodeReaderBundle
import DynamsoftLicense
import SwiftUI

struct ContentView: View {
    @State private var scanResult: String = "Scan results will appear here"

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                Text(scanResult)
                    .font(.system(size: 20))
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .lineSpacing(4)
            }
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    presentBarcodeScanner(mode: .single)
                }) {
                    Text("Single Scan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }

                Button(action: {
                    presentBarcodeScanner(mode: .multiple)

                }) {
                    Text("Multi Scan")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGroupedBackground))
    }

    func presentBarcodeScanner(mode: ScanningMode) {
        let config = BarcodeScannerConfig()
        config.license = "LICENSE-KEY"
        config.scanningMode = mode

        var scannerView = BarcodeScannerView(config: config)
        scannerView.onScannedResult = { result in
            DispatchQueue.main.async {
                switch result.resultStatus {
                case .finished:
                    let items = result.barcodes

                    if items != nil && items!.count > 0 {
                        var index = 0
                        self.scanResult = ""
                        for item in items! {
                            if item.type == .barcode {
                                self.scanResult +=
                                    "Result \(index): \nFormat: \(item.formatString)\nText: \(item.text)\n\n"
                                index += 1
                            }
                        }
                    }

                case .canceled:
                    self.scanResult = "Scan canceled"
                case .exception:
                    self.scanResult = result.errorString ?? "Unknown error"
                @unknown default:
                    break
                }

                UIApplication.shared.windows.first?.rootViewController?.dismiss(
                    animated: true, completion: nil)
            }
        }

        // Present the scanner view modally
        UIApplication.shared.windows.first?.rootViewController?.present(
            UIHostingController(rootView: scannerView),
            animated: true,
            completion: nil
        )
    }
}

#Preview {
    ContentView()
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let config: BarcodeScannerConfig
    var onScannedResult: ((BarcodeScanResult) -> Void)?

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let vc = BarcodeScannerViewController()
        vc.config = config
        vc.onScannedResult = onScannedResult
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context)
    {}
}
