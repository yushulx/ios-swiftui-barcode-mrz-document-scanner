import SwiftUI
import UIKit
import DynamsoftCaptureVisionBundle

struct AutoCaptureSettingsSheet: View {
    @EnvironmentObject private var store: DocumentScannerStore

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Enable auto capture", isOn: $store.autoCaptureSettings.autoCaptureEnabled)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("IoU threshold")
                        Spacer()
                        Text(store.autoCaptureSettings.iouThreshold.formatted(.number.precision(.fractionLength(2))))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $store.autoCaptureSettings.iouThreshold, in: 0.5...0.98)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Area delta threshold")
                        Spacer()
                        Text(store.autoCaptureSettings.areaDeltaThreshold.formatted(.number.precision(.fractionLength(2))))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $store.autoCaptureSettings.areaDeltaThreshold, in: 0.02...0.30)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Stable frame count")
                        Spacer()
                        Text("\(store.autoCaptureSettings.stableFrameCount)")
                            .foregroundStyle(.secondary)
                    }
                    Stepper(value: $store.autoCaptureSettings.stableFrameCount, in: 1...8) {
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Stabilization")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.showSettings = false
                    }
                }
            }
        }
    }
}

struct QuadEditorSheet: View {
    let page: ScannedPage
    let onApply: (Quadrilateral) -> Void
    let onCancel: () -> Void

    @StateObject private var session = QuadEditorSession()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    onCancel()
                }

                Spacer()

                Text("Adjust Crop")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Spacer()

                Button("Apply") {
                    if let quad = session.currentQuad() {
                        onApply(quad)
                    } else {
                        onCancel()
                    }
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.thinMaterial)

            if page.originalImageData != nil {
                QuadEditorRepresentable(page: page, session: session)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                Spacer()
                Text("This page does not have an editable source image.")
                Spacer()
            }
        }
    }
}

final class QuadEditorSession: ObservableObject {
    weak var coordinator: QuadEditorRepresentable.Coordinator?

    func currentQuad() -> Quadrilateral? {
        coordinator?.currentQuad()
    }
}

struct QuadEditorRepresentable: UIViewRepresentable {
    let page: ScannedPage
    let session: QuadEditorSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> ImageEditorView {
        let editorView = ImageEditorView()
        context.coordinator.editorView = editorView
        editorView.tipVisible = false

        if let imageData = page.originalImageData {
            editorView.imageData = imageData
        }

        context.coordinator.installQuad(page.quad)
        return editorView
    }

    func updateUIView(_ uiView: ImageEditorView, context: Context) {
        context.coordinator.editorView = uiView
    }

    final class Coordinator: NSObject {
        weak var editorView: ImageEditorView?
        private let session: QuadEditorSession

        init(session: QuadEditorSession) {
            self.session = session
            super.init()
            session.coordinator = self
        }

        func installQuad(_ quad: Quadrilateral?) {
            guard let editorView, let quad else { return }
            let layer = editorView.getDrawingLayer(ddnDrawingLayerId) ?? editorView.createDrawingLayer()
            let item = QuadDrawingItem(quadrilateral: quad)
            layer.drawingItems = [item]
        }

        func currentQuad() -> Quadrilateral? {
            guard let editorView else { return nil }
            let layer = editorView.getDrawingLayer(ddnDrawingLayerId) ?? editorView.createDrawingLayer()
            guard let item = layer.drawingItems?.first as? QuadDrawingItem else {
                return nil
            }
            return cloneQuadrilateral(item.quad)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}