# iOS SwiftUI MRZ Scanner 
The sample demonstrates how to quickly implement an iOS MRZ scanner app using SwiftUI and Dynamsoft Capture Vision.

## Prerequisites
- Click [here](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) to apply for a 30-day FREE Trial license.

## Usage
1. Open the project in Xcode.
2. Set the license key in `CameraViewController.swift`:
    
    ```swift
    LicenseManager.initLicense("LICENSE-KEY", verificationDelegate: self)
    ```

3. Connect an iPhone or iPad to run the app. 

