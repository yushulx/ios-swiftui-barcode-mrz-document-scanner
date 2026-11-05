# Merge Images into a PDF on iOS

Pick several photos with `PHPickerViewController`, optionally auto-crop each one with Dynamsoft Document Normalizer, choose a color mode, and write the normalized pages into a single multi-page PDF that is handed to the iOS share sheet.

## Features

- Unlimited multi-image selection without full photo library permission
- Optional document boundary detection and auto-cropping per image
- Binary, grayscale, or color output per page
- Multi-page PDF assembly with PDFKit
- Share sheet export to Files, Mail, and other apps

## Requirements

- Xcode 16+
- iOS 15+
- [Get a 30-day free trial license](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform)

## Setup

```bash
cd examples/MergeImagesToPDF
pod install
open PDFCreator.xcworkspace
```

## Build From Terminal

```bash
cd examples/MergeImagesToPDF
pod install
xcodebuild -workspace PDFCreator.xcworkspace -scheme PDFCreator -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## Notes

- The Podfile pins `DynamsoftCaptureVisionBundle` 3.6.4000, which replaced the six separate 2.x pods (`DynamsoftCaptureVisionRouter`, `DynamsoftCore`, `DynamsoftDocumentNormalizer`, `DynamsoftImageProcessing`, `DynamsoftLicense`, `DynamsoftUtility`).
- Document results are read from `CapturedResult.processedDocumentResult.deskewedImageResultItems`.
- `ImageIO.saveToFile(_:path:overWrite:)` overwrites the target file, so appending every page through it produces a one-page PDF. The sample collects `PDFPage` objects instead and writes the multi-page file with PDFKit.

## Blog

[Merge Multiple Images into One PDF on iOS Using Swift](https://www.dynamsoft.com/codepool/ios-merge-images-to-pdf-swift.html)
