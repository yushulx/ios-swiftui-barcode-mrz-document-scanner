# iOS SwiftUI MRZ Scanner

A SwiftUI app that scans Machine Readable Zones (MRZ) on passports and ID cards in real-time using the device camera. Built with **Dynamsoft Capture Vision** SDK.

## Features

- **Real-time MRZ recognition** — Reads passports (TD3), ID cards (TD1/TD2), and visas automatically
- **Document boundary detection** — Detects the document outline and draws a live overlay quad
- **Portrait zone extraction** — Identifies and crops the face photo from the document
- **Multi-frame cross-verification** — Filters results across frames for stable, accurate output
- **Live camera overlays** — Document quad (DDN layer), MRZ text lines (DLR layer), and portrait zone (custom cyan layer) rendered on the camera preview
- **Structured result display** — Parsed fields (name, document number, nationality, age, dates) shown in a clean result view

## Requirements

- iOS 16.0+
- Xcode 15+
- Swift 5.9+
- A physical device with camera (simulator does not support camera input)

## SDK Dependencies (via SPM)

| Package | Version | Purpose |
|---------|---------|---------|
| [capture-vision-spm](https://github.com/Dynamsoft/capture-vision-spm) | 3.4.1200 | Core vision engine: CameraEnhancer, CaptureVisionRouter, ImageProcessor |
| [mrz-scanner-spm](https://github.com/Dynamsoft/mrz-scanner-spm) | 3.4.1300 | MRZ template pipeline: IdentityProcessor, code parser, MRZ templates |

## License

The app uses a built-in trial license. For production use, obtain a license key from:

[https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform)

## How to Build

1. Clone the repository
2. Open `MrzScanner.xcodeproj` in Xcode
3. Wait for SPM packages to resolve
4. Select a physical iOS device as the run destination
5. Build and run

## Project Structure

```
MrzScanner/
├── MrzScannerApp.swift        # App entry point with NavigationStack
├── ContentView.swift           # Camera preview UI with overlays and capture button
├── ScannerController.swift     # Core scanning pipeline (DCE + CVR pipeline management)
├── CameraPreview.swift         # UIViewRepresentable bridging DCE CameraView to SwiftUI
├── ScanResultView.swift        # Parsed MRZ data display (profile, document info, personal info)
├── MrzParser.swift             # MRZ field extraction and formatting from ParsedResultItem
└── mrz-mobile.json             # Capture Vision template (ReadPassportAndId, ReadPassport, ReadId)
```

## Architecture

The scanning pipeline is managed by `ScannerController` (an `ObservableObject`), which orchestrates:

1. **CameraEnhancer** — Controls the device camera and frame capture via `CameraView`
2. **CaptureVisionRouter** — Runs the "ReadPassportAndId" template pipeline on each frame
3. **MultiFrameResultCrossFilter** — Verifies document quads and text lines across frames for stability
4. **CapturedResultReceiver** — Receives final results: parsed MRZ fields, document quad, deskewed image
5. **IntermediateResultReceiver** — Receives intermediate pipeline units (scaled image, localized text lines, detected quads) for portrait zone computation
6. **IdentityProcessor** — Computes portrait zone from intermediate results using `findPortraitZone()`

Drawing overlays use the `CameraView`'s `DrawingLayer` API:
- **Layer 1 (DDN)** — Document boundary quad
- **Layer 3 (DLR)** — MRZ text line regions
- **Custom layer (100+)** — Portrait zone with cyan stroke style

## Supported Document Types

| Type | Format | MRZ Lines |
|------|--------|-----------|
| Passport | TD3 | 2 lines × 44 characters |
| ID Card | TD1 | 3 lines × 30 characters |
| ID Card | TD2 | 2 lines × 36 characters |
| Visa | MRVA/MRVB | 2 lines × 44 or 36 characters |
