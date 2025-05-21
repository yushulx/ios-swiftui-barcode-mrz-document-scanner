import DynamsoftMRZScannerBundle
import SwiftUI

struct ContentView: View {
    @State private var scanResult: String = ""
    @State private var scanMode: ScanMode = .mrz

    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Radio Group UI
            HStack(spacing: 24) {
                modeButton(title: "MRZ", mode: .mrz)
                modeButton(title: "VIN", mode: .vin)
            }
            .padding(.top, 16)

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

    @ViewBuilder
    func modeButton(title: String, mode: ScanMode) -> some View {
        Button(action: {
            scanMode = mode
            scanResult = ""  // clear result on mode switch
        }) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.orange, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if scanMode == mode {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(title)
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .medium))
            }
        }
    }

    func presentScanner() {
        let config = ScannerConfig()
        config.license =
            "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ=="
        config.mode = scanMode

        var scannerView = MRZScannerView(config: config)
        scannerView.onScannedResult = { result in
            DispatchQueue.main.async {
                switch result.resultStatus {
                case .finished:
                    switch scanMode {
                    case .mrz:
                        let mrzResult = result as? MRZScanResult
                        if let data = mrzResult?.data {
                            self.scanResult +=
                                "Name: " + data.firstName + " " + data.lastName + "\n\n"
                            self.scanResult += "Sex: " + data.sex.capitalized + "\n\n"
                            self.scanResult += "Age: " + String(data.age) + "\n\n"
                            self.scanResult += "Document Type: " + data.documentType + "\n\n"
                            self.scanResult += "Document Number: " + data.documentNumber + "\n\n"
                            self.scanResult += "Issuing State: " + data.issuingState + "\n\n"
                            self.scanResult += "Nationality: " + data.nationality + "\n\n"
                            self.scanResult += "Date Of Birth: " + data.dateOfBirth + "\n\n"
                            self.scanResult += "Date Of Expire: " + data.dateOfExpire + "\n\n"
                        }
                    case .vin:
                        let vinResult = result as? VINScanResult
                        if let data = vinResult?.data {
                            self.scanResult += "VIN String: " + data.vinString + "\n\n"
                            self.scanResult += "WMI: " + data.wmi + "\n\n"
                            self.scanResult += "Region: " + data.region + "\n\n"
                            self.scanResult += "VDS: " + data.vds + "\n\n"
                            self.scanResult += "Check Digit: " + data.checkDigit + "\n\n"
                            self.scanResult += "Model Year: " + data.modelYear + "\n\n"
                            self.scanResult += "Manufacturer plant: " + data.plantCode + "\n\n"
                            self.scanResult += "Serial Number: " + data.serialNumber + "\n\n"
                        }
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

                rootVC?.dismiss(animated: true, completion: nil)
            }
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
    let config: ScannerConfig
    var onScannedResult: ((ScanResultBase) -> Void)?

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.config = config
        vc.onScannedResult = onScannedResult
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}
