import SwiftUI

struct ContentView: View {
    @State private var image: NSImage?
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
            
            
        }

        .onChange(of: image) {
            if image != nil {
                isShowingImage = true
            }
        }
    }
}
