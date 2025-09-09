import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var showingResultView = false
    @State private var showingPermissions = false
    @State private var capturedImage: UIImage?
    @State private var ocrResults: [String] = []
    @StateObject private var permissionsManager = PermissionsManager()
    
    var body: some View {
        NavigationView {
            Group {
                if permissionsManager.isCameraAuthorized {
                    CameraView(
                        onImageCaptured: { image, ocrText in
                            print("ContentView: Image captured callback received")
                            capturedImage = image
                            ocrResults = ocrText
                            showingResultView = true
                            print("ContentView: Setting showingResultView to true")
                        }
                    )
                } else {
                    PermissionDeniedView {
                        showingPermissions = true
                    }
                }
            }
            .navigationTitle("ID Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingResultView) {
                if let image = capturedImage {
                    ResultView(image: image, ocrResults: ocrResults)
                }
            }
            .sheet(isPresented: $showingPermissions) {
                PermissionsView(permissionsManager: permissionsManager, isPresented: $showingPermissions)
            }
        }
        .onAppear {
            checkPermissions()
        }
        .onChange(of: permissionsManager.isCameraAuthorized) { _, isAuthorized in
            if isAuthorized {
                // Dismiss the permissions sheet when camera is authorized
                showingPermissions = false
            }
        }
    }
    
    private func checkPermissions() {
        permissionsManager.checkPermissions()
        if !permissionsManager.isCameraAuthorized {
            showingPermissions = true
        }
    }
}

struct PermissionDeniedView: View {
    let onRequestPermissions: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("ID Scanner needs camera access to scan documents and detect faces.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Grant Camera Access") {
                onRequestPermissions()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
