import AVFoundation
import Photos
import SwiftUI

class PermissionsManager: ObservableObject {
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    
    init() {
        checkPermissions()
        // Start monitoring permission changes
        startMonitoringPermissions()
    }
    
    func checkPermissions() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryPermissionStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    
    private func startMonitoringPermissions() {
        // Monitor app becoming active to refresh permissions
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPermissions()
        }
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.checkPermissions() // Refresh all permissions after request
            }
        }
    }
    
    func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                self?.checkPermissions() // Refresh all permissions after request
            }
        }
    }
    
    var isCameraAuthorized: Bool {
        cameraPermissionStatus == .authorized
    }
    
    var isPhotoLibraryAuthorized: Bool {
        photoLibraryPermissionStatus == .authorized
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("ID Scanner needs camera access to scan documents and detect faces for verification.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "camera",
                    title: "Camera",
                    description: "Required for document scanning",
                    status: permissionsManager.cameraPermissionStatus,
                    action: permissionsManager.requestCameraPermission
                )
                
                PermissionRow(
                    icon: "photo.on.rectangle",
                    title: "Photo Library",
                    description: "Optional for saving scanned documents",
                    status: permissionsManager.photoLibraryPermissionStatus,
                    action: permissionsManager.requestPhotoLibraryPermission
                )
            }
            .padding(.horizontal)
            
            if permissionsManager.isCameraAuthorized {
                Button("Continue") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            permissionsManager.checkPermissions()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: Any
    let action: () -> Void
    
    private var statusText: String {
        if let cameraStatus = status as? AVAuthorizationStatus {
            switch cameraStatus {
            case .authorized:
                return "Granted"
            case .denied, .restricted:
                return "Denied"
            case .notDetermined:
                return "Not Requested"
            @unknown default:
                return "Unknown"
            }
        } else if let photoStatus = status as? PHAuthorizationStatus {
            switch photoStatus {
            case .authorized, .limited:
                return "Granted"
            case .denied, .restricted:
                return "Denied"
            case .notDetermined:
                return "Not Requested"
            @unknown default:
                return "Unknown"
            }
        }
        return "Unknown"
    }
    
    private var isGranted: Bool {
        if let cameraStatus = status as? AVAuthorizationStatus {
            return cameraStatus == .authorized
        } else if let photoStatus = status as? PHAuthorizationStatus {
            return photoStatus == .authorized || photoStatus == .limited
        }
        return false
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Allow") {
                    action()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
