# BarcodeBenchmark iOS

An iOS application that benchmarks barcode scanning performance across four SDKs side-by-side:

| SDK | Type | Color |
|-----|------|-------|
| **Dynamsoft Barcode Reader** | Commercial | Blue overlay |
| **Google ML Kit** | Free | Green overlay |
| **Apple Vision** | Native iOS | Purple overlay |
| **ZXing-CPP** | Open source | Orange overlay |

https://github.com/user-attachments/assets/3fb3b202-ff92-4501-a0e6-316871efd95a

## Features

### Benchmark Modes
| Mode | Description |
|------|-------------|
| **Image** | Pick an image from the photo library; all 4 SDKs decode it and report per-frame time |
| **Video** | Process every frame of a video and compare multi-frame throughput |
| **Live Camera** | Real-time camera feed with bounding-box overlays per scanner |

### Live Camera Overlay
Each scanner view draws colored bounding boxes around every detected barcode in real time, with a format label pill above each box (e.g. `QR_CODE`, `CODE_128`). Overlays are cleared automatically when no barcode is in view. All four SDKs — including ZXing-CPP — support live overlay.

### Remote Benchmark (Web Server)
- Built-in HTTP server on port 8080
- Upload images or videos from a desktop browser
- Batch-process multiple files without touching the device
- **Export Report** — download a styled HTML report with SDK comparison bar charts (barcodes detected + processing time) and a per-file results table

### Resolution Config
Select **720P** (1280 × 720) or **1080P** (1920 × 1080) before starting any camera test.

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.0+
- CocoaPods (for Google ML Kit)

## Setup

### 1. Install Google ML Kit via CocoaPods

ML Kit is not available through Swift Package Manager, so it is installed via CocoaPods.

```bash
cd BarcodeBenchmarkiOS
pod install
```

Then **open `BarcodeBenchmark.xcworkspace`** (not `.xcodeproj`) for all subsequent builds.

### 2. Dynamsoft Barcode Reader (SPM — automatic)

The `barcode-reader-spm` package (`v11.4.1200`) is already declared in `project.pbxproj`. Xcode resolves it automatically on first build.

Request a [30-day free key](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform).

### 3. Apple Vision

Native iOS framework — no additional setup required.

### 4. ZXing-CPP (SPM — automatic)

The `zxing-cpp` package (`v2.3.0+`) is already declared in `project.pbxproj`. Xcode resolves it automatically on first build. See the [ZXing-CPP iOS wrapper](https://github.com/zxing-cpp/zxing-cpp/tree/master/wrappers/ios) for details.
