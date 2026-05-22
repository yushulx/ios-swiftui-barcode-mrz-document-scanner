import SwiftUI
import DynamsoftCaptureVisionBundle

@main
struct DynamsoftDocumentScannerApp: App {
    @StateObject private var store = DocumentScannerStore()

    init() {
        LicenseManager.initLicense(
            "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjM0ODEwLU1qTTBPREV3TFZSeWFXRnNVSEp2YWciLCJtYWluU2VydmVyVVJMIjoiaHR0cHM6Ly9tZGxzLmR5bmFtc29mdG9ubGluZS5jb20vIiwib3JnYW5pemF0aW9uSUQiOiIyMzQ4MTAiLCJzdGFuZGJ5U2VydmVyVVJMIjoiaHR0cHM6Ly9zZGxzLmR5bmFtc29mdG9ubGluZS5jb20vIiwiY2hlY2tDb2RlIjoxNzYwOTE2OTkyfQ==",
            verificationDelegate: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
