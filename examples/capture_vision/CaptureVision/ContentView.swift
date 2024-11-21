import SwiftUI

struct ContentView: View {
    @State private var image: ImageType?
    @State private var shouldCapturePhoto = false
    @State private var isShowingImage = false

    var body: some View {
        ZStack {
            if isShowingImage, let capturedImage = image {
                // Show ImageViewer
                ImageViewer(image: capturedImage, isShowingImage: $isShowingImage)
            } else {
                // Camera Preview
                CameraView(image: $image, shouldCapturePhoto: $shouldCapturePhoto)
                    .edgesIgnoringSafeArea(.all)

                // Capture Button
                VStack {
                    Spacer()
                    Button(action: {
                        shouldCapturePhoto = true
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.8), lineWidth: 2)
                            )
                            .shadow(radius: 10)
                    }
                    .padding(.bottom, 40)
                }
            }
        }.onAppear {
            // Initialize the license here
            let licenseKey =
                "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ=="
            
#if os(iOS)

#elseif os(macOS)
            let result = CaptureVisionWrapper.initializeLicense(licenseKey)
            if result == 0 {
                print("License initialized successfully")
            } else {
                print("Failed to initialize license with error code: \(result)")
            }
#endif
            
        }

        #if os(iOS)
            .onChange(of: image) { _ in
                if image != nil {
                    isShowingImage = true
                }
            }
        #elseif os(macOS)
            .onChange(of: image) {
                if image != nil {
                    isShowingImage = true
                }
            }
        #endif
    }
}
