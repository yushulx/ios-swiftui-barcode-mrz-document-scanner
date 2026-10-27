# iOS SwiftUI Examples for Barcode, MRZ and Document Scanning
This repository contains examples of using the Dynamsoft Capture Vision SDK to detect 1D/2D barcodes, documents, and MRZ (Machine Readable Zone).


## Prerequisites
- Click [here](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) to apply for a 30-day FREE Trial license.
- All examples are pinned to **Dynamsoft Barcode Reader v11.6.4000** and **Dynamsoft Capture Vision v3.6.4000** through Swift Package Manager ([barcode-reader-spm](https://github.com/Dynamsoft/barcode-reader-spm) / [capture-vision-spm](https://github.com/Dynamsoft/capture-vision-spm)). The MRZ Scanner examples use [mrz-scanner-spm](https://github.com/Dynamsoft/mrz-scanner-spm) v3.6.2000.
- `examples/dbrbundle` is a legacy v10 wrapper kept at Dynamsoft Barcode Reader 10.4.3001: its framework product is also named `DynamsoftBarcodeReaderBundle`, which collides with the framework name shipped inside barcode-reader-spm 11.x. Use `examples/barcode` for the v11 way.
- The macOS C++ samples (`examples/capture_vision`, `examples/document`) link the prebuilt Dynamsoft Capture Vision C++ libraries vendored in `examples/dcv` — currently **DCV 3.6.40.9167 / DBR 11.6.40.9167** with universal arm64 + x86_64 dylibs.
- Xcode 16+ with an iOS 16+ deployment target (some examples require iOS 17/18; check each project's deployment target).

## Examples
- [Barcode Scanning](./examples/barcode/)
    
    https://user-images.githubusercontent.com/2202306/156506394-7fccfdd2-5be6-4533-883c-b694034a2afa.mp4

- [MRZ Scanning](./examples/mrz/)

    https://github.com/user-attachments/assets/09b6151d-c285-451b-9467-3079a2414c82

- [macOS Barcode Scanner](./examples/capture_vision/)
    
    https://github.com/user-attachments/assets/321fa8ce-8f38-4c7a-bb50-93c1cd1b152f

- [iOS Document Scanner](./examples/document/)
    
    https://github.com/user-attachments/assets/5f056487-519b-45f1-9900-b3bc212a58a9