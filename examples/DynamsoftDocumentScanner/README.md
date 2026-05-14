# Dynamsoft Document Scanner for iOS

SwiftUI iOS document scanner with live camera capture, multi-page review, crop adjustment, and PDF or image export.

https://github.com/user-attachments/assets/f4d2b775-8f56-4c5c-834f-0f74338f1c12

## Features

- Live camera scanning with Dynamsoft Capture Vision
- Auto capture stabilization with customizable thresholds
- Manual capture fallback to the latest frame
- Gallery import with document detection
- Multi-page session management
- Per-page filter selection: color, grayscale, binary
- Rotate, retake, adjust crop, reorder pages
- Export as PDF or individual JPEG images through the iOS share sheet

## Requirements

- Xcode 16+
- iOS 16+
- [Get a 30-day free trial license](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform)

## Setup

```bash
cd examples/DynamsoftDocumentScanner
open DynamsoftDocumentScanner.xcodeproj
```

## Build From Terminal

```bash
cd examples/DynamsoftDocumentScanner
xcodebuild -resolvePackageDependencies -project DynamsoftDocumentScanner.xcodeproj -scheme DynamsoftDocumentScanner
xcodebuild -project DynamsoftDocumentScanner.xcodeproj -scheme DynamsoftDocumentScanner -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## Notes

- The project uses the Swift Package `https://github.com/Dynamsoft/capture-vision-spm`.
- The app links the `DynamsoftCaptureVisionBundle` framework.
- The app initializes the SDK in `DynamsoftDocumentScannerApp.swift`. Replace the license string with your own license if needed.

