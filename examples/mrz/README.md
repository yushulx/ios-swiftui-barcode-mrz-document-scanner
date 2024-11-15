# iOS SwiftUI MRZ Scanner 
The sample demonstrates how to quickly implement an iOS MRZ scanner app using SwiftUI and Dynamsoft Capture Vision.

https://github.com/user-attachments/assets/09b6151d-c285-451b-9467-3079a2414c82

## Prerequisites
- Click [here](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) to apply for a 30-day FREE Trial license.

## Usage
1. Open the project in Xcode.
2. Set the license key in `CameraViewController.swift`:
    
    ```swift
    LicenseManager.initLicense("LICENSE-KEY", verificationDelegate: self)
    ```

3. Connect an iPhone or iPad to run the app. 

