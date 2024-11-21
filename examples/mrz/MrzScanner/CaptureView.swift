import SwiftUI

struct CaptureView: View {
    var title: String
    var body: some View {
        VStack {
            CameraViewControllerRepresentable()
        }
        .navigationTitle(title)
        .padding()
    }
}

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        return vc
    }

    func updateUIViewController(_ viewController: CameraViewController, context: Context) {

    }
}
