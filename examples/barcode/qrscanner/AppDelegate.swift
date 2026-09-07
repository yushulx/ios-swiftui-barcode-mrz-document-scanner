import SwiftUI
import UIKit
import DynamsoftCaptureVisionBundle

// Shared state that surfaces license verification errors as a SwiftUI alert.
class LicenseState: ObservableObject {
    static let shared = LicenseState()
    @Published var isErrorPresented = false
    @Published var errorMessage = ""
}

class AppDelegate: UIResponder, UIApplicationDelegate, LicenseVerificationListener {

    func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
        if !isSuccess {
            let message = error?.localizedDescription ?? "Unknown error"
            print("\(message)")
            DispatchQueue.main.async {
                LicenseState.shared.errorMessage =
                    "\(message)\n\nPlease check the license key in AppDelegate.swift."
                LicenseState.shared.isErrorPresented = true
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Request a trial license: https://www.dynamsoft.com/customer/license/trialLicense?product=dbr
        LicenseManager.initLicense("DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ==", verificationDelegate: self)
        return true
    }
}
