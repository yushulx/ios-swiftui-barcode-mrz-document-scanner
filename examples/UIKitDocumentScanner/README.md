# UIKit iOS Document Scanner with Auto Capture

A UIKit document scanner in Swift that streams `AVFoundation` frames into Dynamsoft Capture Vision, auto-captures when the detected document boundary is stable for three frames, lets the user drag the four corners, and then deskews the page to a binary image.

## Features

- Real-time document boundary detection from the camera feed
- Automatic photo capture once three consecutive quads agree (IoU > 0.9)
- Manual corner adjustment on the crop screen
- Perspective correction and binarization with Dynamsoft Document Normalizer
- Save the normalized page to the photo library

## Requirements

- Xcode 16+
- iOS 15+
- A physical iPhone (the Simulator has no camera)
- [Get a 30-day free trial license](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform)

## Setup

```bash
cd examples/UIKitDocumentScanner
pod install
open "Document Scanner.xcworkspace"
```

Replace the trial license string in `Document Scanner/AppDelegate.swift` with your own license if needed.

## Build From Terminal

```bash
cd examples/UIKitDocumentScanner
pod install
xcodebuild -workspace "Document Scanner.xcworkspace" -scheme "Document Scanner" -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## Notes

- The Podfile pins `DynamsoftCaptureVisionBundle` 3.6.4000, which replaced the separate `DynamsoftCore` / `DynamsoftCaptureVisionRouter` / `DynamsoftDocumentNormalizer` pods.
- Document results are read from `CapturedResult.processedDocumentResult`: `detectedQuadResultItems` for boundaries and `deskewedImageResultItems` for the normalized page.
- `Quadrilateral` takes `[NSValue]`, so wrap each `CGPoint` with `NSValue(cgPoint:)`.

## Blog

[How to Build an iOS Document Scanner App in Swift with AVFoundation](https://www.dynamsoft.com/codepool/ios-document-scanner.html)
