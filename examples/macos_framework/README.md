# Building macOS Framework with Dynamsoft Barcode Reader C++ SDK 
The project aims to build a macOS framework based on the Dynamsoft Barcode Reader C++ SDK. It simplifies the integration of barcode scanning into macOS Swift applications.

https://github.com/user-attachments/assets/c7d88ff9-2911-4d55-89b8-b41dc399f4ab

## Prerequisites
- [Dynamsoft Barcode Reader C++ SDK](https://download2.dynamsoft.com/dbr/dynamsoft-barcode-reader-cpp-mac-10.4.2000.250110.zip)
- [Trial License Key](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) for running the sample code.

## Usage
1. Open the `Test` project in Xcode. 
2. Set the license key in `Test/Test/CameraViewController.swift`:

    ```swift
    let licenseKey =  "LICENSE-KEY"
    let result = CaptureVisionWrapper.initializeLicense(licenseKey)
    ```

3. Build and run the project.
   ![macOS framework for barcode scanning](https://www.dynamsoft.com/codepool/img/2025/01/macos-framework-barcode-detection.png)

## Blog
[Building a macOS Framework with Objective-C++ and C++ for Swift Barcode Detection](https://www.dynamsoft.com/codepool/build-macos-framework-objc-cpp.html)
