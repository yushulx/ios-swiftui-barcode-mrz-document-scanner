# iOS Barcode QR Code Scanner in SwiftUI
The sample demonstrates how to quickly implement an iOS Barcode QR code scanner app using [SwiftUI](https://developer.apple.com/xcode/swiftui/) and the **Dynamsoft Barcode Reader Bundle** distributed as a Swift package ([Dynamsoft/barcode-reader-spm](https://github.com/Dynamsoft/barcode-reader-spm)).

## SDK
- [Dynamsoft Barcode Reader Bundle 11.6.2000](https://github.com/Dynamsoft/barcode-reader-spm) (Swift package product `DynamsoftBarcodeReader`)
- [Dynamsoft Capture Vision Bundle 3.6.2000](https://github.com/Dynamsoft/capture-vision-spm) (resolved automatically as a package dependency; provides `CaptureVisionRouter`, `CameraEnhancer` and `LicenseManager`)

A valid license key is required for the barcode SDK. Click [here](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) to apply for a 30-day FREE Trial license.

## Usage
1. Open the project in Xcode. The Swift package is resolved and the SDK framework is downloaded automatically when the project is opened or built:

    ```bash
    open qrscanner.xcodeproj
    ```

    If you prefer the command line:

    ```bash
    xcodebuild -project qrscanner.xcodeproj -scheme qrscanner -destination 'generic/platform=iOS Simulator' build
    ```

2. Set the license key in `AppDelegate.swift`:

    ```swift
    import UIKit
    import DynamsoftCaptureVisionBundle

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

3. Connect an iPhone or iPad to run the app. The camera permission string is already configured in the project's `Info.plist` keys.

    https://user-images.githubusercontent.com/2202306/156506394-7fccfdd2-5be6-4533-883c-b694034a2afa.mp4

## How It Works
- `CameraManager.swift` builds the capture pipeline: `CaptureVisionRouter` + `CameraEnhancer` + `CameraView`, starts the video barcode reading with the preset template `PresetTemplate.readBarcodes`, and receives results through the `CapturedResultReceiver` callback `onDecodedBarcodesReceived`.
- `DynamsoftCameraView.swift` wraps the `CameraView` for SwiftUI.
- Decoded barcodes are highlighted on the camera view and listed in the result panel.

## Blog
[Building iOS QR Code Scanner with SwiftUI on M1 Mac](https://www.dynamsoft.com/codepool/ios-qr-code-scanner-swiftui-m1-mac.html)
