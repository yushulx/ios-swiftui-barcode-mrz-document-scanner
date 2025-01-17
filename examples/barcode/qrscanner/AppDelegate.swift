import DynamsoftLicense
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate, LicenseVerificationListener {

    func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
        if !isSuccess {
            if let error = error {
                print("\(error.localizedDescription)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Request a trial license: https://www.dynamsoft.com/customer/license/trialLicense?product=dbr
        LicenseManager.initLicense("LICENSE-KEY", verificationDelegate: self)
        return true
    }
}
