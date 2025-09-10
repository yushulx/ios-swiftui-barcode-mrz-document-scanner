import SwiftUI
import AVFoundation

// Main container that handles navigation between camera and results
struct ContentView: View {
    @StateObject private var permissionsManager = PermissionsManager()
    @State private var showingPermissions = false
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if permissionsManager.isCameraAuthorized {
                    CameraContainerView(navigationPath: $navigationPath)
                } else {
                    PermissionDeniedView {
                        showingPermissions = true
                    }
                }
            }
            .navigationTitle("ID Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CapturedImageData.self) { imageData in
                ResultView(image: imageData.image, ocrResults: imageData.ocrResults)
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

// Data structure for navigation
struct CapturedImageData: Hashable {
    let image: UIImage
    let ocrResults: [String]
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(image.size.width)
        hasher.combine(image.size.height)
        hasher.combine(ocrResults)
    }
    
    static func == (lhs: CapturedImageData, rhs: CapturedImageData) -> Bool {
        return lhs.image.size == rhs.image.size && lhs.ocrResults == rhs.ocrResults
    }
}

// Container for camera view that handles navigation
struct CameraContainerView: View {
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        CameraView(
            onImageCaptured: { image, ocrText in
                DispatchQueue.main.async {
                    let imageData = CapturedImageData(image: image, ocrResults: ocrText)
                    navigationPath.append(imageData)
                }
            }
        )
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

