# ID Scanner App

A **SwiftUI**-based document scanning application featuring real-time detection, OCR, and MRZ processing capabilities. This app demonstrates modern iOS development with camera integration, computer vision, and document processing.


## ✨ Features

### 🆓 Free Features
- **Face Detection**: Real-time face detection using iOS Vision framework
- **Document Detection/Rectification**: Automatic document boundary detection and perspective correction for captured documents
- **OCR (Optical Character Recognition)**: Text extraction from documents using iOS Vision framework


### 💼 Commercial Features
- **MRZ (Machine Readable Zone) Scanning**: Passport and ID card MRZ processing using Dynamsoft SDK. Get a [30-day free trial license](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) to try.

## 🛠 Technical Stack

- **Framework**: SwiftUI
- **Language**: Swift
- **Minimum iOS**: 14.0
- **Camera**: AVFoundation
- **Computer Vision**: iOS Vision Framework
- **MRZ Processing**: [Dynamsoft MRZ Scanner SDK](https://github.com/Dynamsoft/mrz-scanner-spm)

## 📋 Requirements

- Xcode 15.0 or later
- iOS 14.0 or later
- Camera access permission
- Device with camera (does not work on simulator for camera features)

## 📦 Dependencies

The project uses Swift Package Manager for dependency management:

- **[Dynamsoft MRZ Scanner](https://github.com/Dynamsoft/mrz-scanner-spm)** (v3.0.5200): Commercial MRZ processing
  - `DynamsoftCaptureVisionBundle`
  - `DynamsoftMRZScannerBundle`

## 🎯 Usage

1. **Launch the app** and grant camera permissions
2. **Point camera at document**: The app will automatically detect document boundaries
3. **Position for capture**: Green overlay indicates optimal positioning
4. **Tap capture button**: 
   - Document is automatically rectified
   - OCR extracts all visible text
   - MRZ processes passport/ID zones (commercial feature)
5. **View results**: Review extracted text and MRZ data

## ⚙️ Configuration

For commercial MRZ features, configure your Dynamsoft license in `CameraManager.swift`:

```swift
LicenseManager.initLicense("YOUR_LICENSE_KEY", verificationDelegate: self)
```











