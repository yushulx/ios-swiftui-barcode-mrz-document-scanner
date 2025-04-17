import SwiftUI
import DynamsoftMRZScannerBundle
import DynamsoftLicense

struct ContentView: View {
    @State private var scanResult: String = ""

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
                    presentScanner()

                }) {
                    Text("START SCANNING")
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

    func presentScanner() {
        let config = MRZScannerConfig()
        config.license = "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ=="

        var scannerView = MRZScannerView(config: config)
        scannerView.onScannedResult = { result in
            DispatchQueue.main.async {
                switch result.resultStatus {
                case .finished:
                    if let data = result.data {
                        self.scanResult += "Name: " + data.firstName + " " + data.lastName + "\n\n"
                        self.scanResult += "Sex: " + data.sex.capitalized + "\n\n"
                        self.scanResult += "Age: " + String(data.age) + "\n\n"
                        self.scanResult += "Document Type: " + data.documentType + "\n\n"
                        self.scanResult += "Document Number: " + data.documentNumber + "\n\n"
                        self.scanResult += "Issuing State: " + data.issuingState + "\n\n"
                        self.scanResult += "Nationality: " + data.nationality + "\n\n"
                        self.scanResult += "Date Of Birth: " + data.dateOfBirth + "\n\n"
                        self.scanResult += "Date Of Expire: " + data.dateOfExpire + "\n\n"
                    }
                    
                case .canceled:
                    self.scanResult = "Scan canceled"
                case .exception:
                    self.scanResult = result.errorString ?? "Unknown error"
                @unknown default:
                    break
                }

                let rootVC = UIApplication.shared.connectedScenes
                                .compactMap { $0 as? UIWindowScene }
                                .flatMap { $0.windows }
                                .first { $0.isKeyWindow }?.rootViewController

                            rootVC?.dismiss(animated: true, completion: nil)            }
        }

        let rootVC = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController

            rootVC?.present(
                UIHostingController(rootView: scannerView),
                animated: true,
                completion: nil
            )
    }
}

#Preview {
    ContentView()
}

struct MRZScannerView: UIViewControllerRepresentable {
    let config: MRZScannerConfig
    var onScannedResult: ((MRZScanResult) -> Void)?

    func makeUIViewController(context: Context) -> MRZScannerViewController {
        let vc = MRZScannerViewController()
        vc.config = config
        vc.onScannedResult = onScannedResult
        return vc
    }

    func updateUIViewController(_ uiViewController: MRZScannerViewController, context: Context)
    {}
}
