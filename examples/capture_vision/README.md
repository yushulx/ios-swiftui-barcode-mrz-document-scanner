## macOS & iOS Barcode Scanner with SwiftUI
This sample demonstrates how to build a macOS & iOS barcode scanner with SwiftUI and Dynamsoft Capture Vision SDK.

## Demo Video
- macOS Barcode Scanner

    https://github.com/user-attachments/assets/321fa8ce-8f38-4c7a-bb50-93c1cd1b152f

- iOS Barcode Scanner

    https://github.com/user-attachments/assets/2c8f722d-0cef-441a-a377-153e87af2918
    
## Prerequisites
- Click [here](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) to apply for a 30-day FREE Trial license.

## SDK Versions
- **macOS**: Dynamsoft Capture Vision C++ SDK `3.6.10` (Barcode Reader `11.6.10`), bundled under `../dcv`. The app decodes each camera frame with the built-in `ReadBarcodes_Default` preset template through the `CaptureVisionWrapper` bridging layer (`dcv.mm`). The SDK loads its preset templates and models from `Templates/` and `Models/` next to its dylibs (`Contents/Frameworks`); the `Copy Dynamsoft Resources` build phase copies `../dcv/resource/{Templates,Models}` into `Contents/Resources` and symlinks them into `Contents/Frameworks` (same approach as [flutter_barcode_sdk_macos](https://github.com/yushulx/flutter_barcode_sdk/tree/main/packages/flutter_barcode_sdk_macos)). macOS 15.7 or later.
- **iOS**: Dynamsoft Capture Vision `3.6.2000` via [capture-vision-spm](https://github.com/Dynamsoft/capture-vision-spm) (`DynamsoftCaptureVisionBundle`). Barcode decoding runs on the raw `BGRA` video frame with `CaptureVisionRouter.captureFromBuffer(...)`.

## Usage
1. Set the license key in `CameraViewController.swift`:

    ```swift
    let licenseKey = "LICENSE-KEY"
    ```

2. Build and run the project for **mac** or **iPhone** in Xcode.
    ![macos barcode scanner](https://www.dynamsoft.com/codepool/img/2024/11/macos-barcode-scanner-swiftui.png)

## Blog
- [How to Build a macOS Barcode Scanner App Using SwiftUI and C++ Barcode SDK from Scratch](https://www.dynamsoft.com/codepool/macos-barcode-scanner-swiftui-cpp.html)
- [How to Create a SwiftUI Barcode Scanner Project for macOS and iOS](https://www.dynamsoft.com/codepool/swiftui-ios-barcode-scanner.html)
