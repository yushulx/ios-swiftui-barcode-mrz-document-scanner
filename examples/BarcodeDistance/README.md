# Barcode Distance Scanner

An iOS app that uses ARKit and **Dynamsoft Barcode Reader** to scan barcodes in real-time and measure the distance between the barcode and the iPhone camera.

https://github.com/user-attachments/assets/301a477f-4990-4d95-9b9c-21b7b6ddc9be

## Prerequisites
- Obtain a [30-day free trial license](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) for Dynamsoft Barcode Reader.

## Features

- **Real-time Barcode Scanning**: Uses Vision framework to detect various barcode types including QR codes, Code 128, EAN, UPC, and more
- **Distance Measurement**: Utilizes ARKit to calculate the real-world distance from the iPhone to the detected barcode
- **Visual Overlay**: Displays barcode information and distance on screen with bounding boxes and annotations
- **Multiple Barcode Support**: Can detect and track multiple barcodes simultaneously

## Requirements

- iOS 14.0 or later
- Device with ARKit support (iPhone 6s or later)
- Camera permissions

## Supported Barcode Types

- QR Code
- Code 128
- Code 39
- Code 93
- EAN-8 / EAN-13
- UPC-E
- PDF417
- Aztec
- Data Matrix
- I2of5
- ITF14
- Micro QR
- GS1 DataBar
- And more...

## How It Works

1. **Camera Activation**: The app opens the camera using ARKit's `ARSCNView`
2. **Barcode Detection**: Each camera frame is processed by Dynamsoft iOS Barcode Reader to identify barcodes
3. **Distance Calculation**: ARKit's hit testing (`hitTest`) is used to determine the 3D position of the barcode relative to the camera
4. **Real-time Display**: Detected barcodes are displayed with:
   - Barcode type badge
   - Barcode value/content
   - Distance measurement (in meters or centimeters)
   - Green bounding box around the barcode

## Usage
1. Open the project in Xcode.
2. Set the Dynamsoft license key in `ARBarcodeScanner.swift`:
   ```swift
   func setLicense() {
        LicenseManager.initLicense(
            "LICENSE-KEY",
            verificationDelegate: self)
    }
   ```
2. Build and run the app on a compatible iPhone device.
3. Point your iPhone camera at a barcode. The app will automatically:
   - Detect the barcode
   - Display the barcode type, value and module size
   - Show the distance measurement in real-time

## Blog
[Measuring Barcode Scanning Performance: Distance vs Module Size with iOS ARKit](https://www.dynamsoft.com/codepool/ios-barcode-scanner-distance-measure.html)
