# Remote Document Scanner for macOS and iOS
This SwiftUI project allows users to retrieve documents from physical document scanners over a network on macOS and iOS. The scanner control relies on Dynamsoft’s RESTful Web API.


https://github.com/user-attachments/assets/49ce6d62-f8cb-4864-9d58-0493f93efc39


## Features
- Cross-platform support for macOS, iOS and iPadOS
- Discover and connect to scanners via IP address
- Scan documents and save them as PDF

## Prerequisites
- Obtain a [trial license](https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform) for Dynamic Web TWAIN.
- Install the Dynamsoft service on your local machine that has a connected scanner.
    - [Windows](https://demo.dynamsoft.com/DWT/Resources/dist/DynamsoftServiceSetup.msi)
    - [Linux](https://demo.dynamsoft.com/DWT/Resources/dist/DynamsoftServiceSetup.deb)
    - [macOS](https://demo.dynamsoft.com/DWT/Resources/dist/DynamsoftServiceSetup.pkg)
- Navigate to `http://127.0.0.1:18625/` to enable remote access by binding the IP address of your machine.
    ![dynamsoft-service-config](https://user-images.githubusercontent.com/2202306/266243200-e2b1292e-dfbd-4821-bf41-70e2847dd51e.png)
## How to Use
1. Download the project and open it in Xcode.
2. Replace the `license` and `ip` in `ContentView.swift` with your own.
    ```swift
    private let licenseKey = "LICENSE-KEY"
    private let apiURL = "http://YOUR-PC-IP:18622"
    ```
3. Run the project on your macOS or iOS device.
4. Use the app to discover available scanners, scan documents, and save them as PDF.
