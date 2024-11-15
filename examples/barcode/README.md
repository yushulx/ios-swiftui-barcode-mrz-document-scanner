# iOS Barcode QR Code Scanner in SwiftUI
The sample demonstrates how to quickly implement an iOS Barcode QR code scanner app using [SwiftUI](https://developer.apple.com/xcode/swiftui/), [Dynamsoft Camera Enhancer](https://www.dynamsoft.com/camera-enhancer/docs/mobile/programming/ios/guide/guide.html) and [Dynamsoft Barcode Reader](https://www.dynamsoft.com/barcode-reader/docs/mobile/programming/objectivec-swift/user-guide.html?lang=swift).

## SDKs
- DynamsoftCameraEnhancer 4.0.2
- Dynamsoft Barcode Reader 10.0.21
   
   A valid license key is required for the barcode SDK. Click [here](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) to apply for a 30-day FREE Trial license.

## Usage
1. Install the dependencies and then open the project in Xcode:

    ```bash
    brew install cocoapods
    pod install
    open qrscanner.xcworkspace
    ```
    
2. Set the license key in `AppDelegate.swift`:
    
    ```swift
    import UIKit
    import DynamsoftLicense

    class AppDelegate: UIResponder, UIApplicationDelegate, LicenseVerificationListener {

        func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
            if !isSuccess {
                if let error = error {
                    print("\(error.localizedDescription)")
                }
            }
        }

        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
            // Request a trial license: https://www.dynamsoft.com/customer/license/trialLicense?product=dbr
            LicenseManager.initLicense("LICENSE-KEY", verificationDelegate: self)
            return true
        }
    }

    ```

3. Connect an iPhone or iPad to run the app. 
    
    https://user-images.githubusercontent.com/2202306/156506394-7fccfdd2-5be6-4533-883c-b694034a2afa.mp4
    
## Blog
[Building iOS QR Code Scanner with SwiftUI on M1 Mac](https://www.dynamsoft.com/codepool/ios-qr-code-scanner-swiftui-m1-mac.html)
