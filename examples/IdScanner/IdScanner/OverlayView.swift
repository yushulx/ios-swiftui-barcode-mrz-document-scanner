import SwiftUI
import AVFoundation
import Vision

struct OverlayView: View {
    let faces: [VNFaceObservation]
    let rectangles: [VNRectangleObservation]
    let previewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Faces
                ForEach(Array(faces.enumerated()), id: \.offset) { idx, face in
                    let r = convertVisionRect(face.boundingBox, layer: previewLayer)
                    if r != .zero {
                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: r.width, height: r.height)
                            .position(x: r.midX, y: r.midY)
                        Text("Face \(idx)")
                            .font(.caption2).bold()
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                            .position(x: r.midX, y: max(r.minY - 12, 10))
                    }
                }

                // Rectangles
                ForEach(Array(rectangles.enumerated()), id: \.offset) { idx, ro in
                    let path = convertVisionRectangleToPath(ro, layer: previewLayer)
                    path.stroke(Color.blue, lineWidth: 3)

                    let bboxL = convertVisionRect(ro.boundingBox, layer: previewLayer)
                    if bboxL != .zero {
                        Text("Document \(idx)")
                            .font(.caption2).bold()
                            .padding(4)
                            .background(Color.white.opacity(0.85))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                            .position(x: bboxL.midX, y: max(bboxL.minY - 12, 10))

                        // Corner dots
                        let tl = convertVisionPoint(ro.topLeft, layer: previewLayer)
                        let tr = convertVisionPoint(ro.topRight, layer: previewLayer)
                        let br = convertVisionPoint(ro.bottomRight, layer: previewLayer)
                        let bl = convertVisionPoint(ro.bottomLeft, layer: previewLayer)
                        Group {
                            dot(.red, at: tl)
                            dot(.green, at: tr)
                            dot(.yellow, at: br)
                            dot(.orange, at: bl)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Helpers (VN -> metadata -> layer)

    @inline(__always)
    private func vnRectToMetadata(_ r: CGRect) -> CGRect {
        // Vision normalized coordinates (origin top-left, Y down)
        // Convert to metadata format (origin top-left, Y down)
        return CGRect(
            x: r.origin.x,
            y: r.origin.y,
            width: r.size.width,
            height: r.size.height
        )
    }

    @inline(__always)
    private func vnPointToMetadata(_ p: CGPoint) -> CGPoint {
        // Vision normalized coordinates (origin top-left, Y down)
        // Convert to metadata format (origin top-left, Y down)
        return CGPoint(x: p.x, y: 1 - p.y)
    }

    private func convertVisionRect(_ vnRect: CGRect,
                                   layer: AVCaptureVideoPreviewLayer?) -> CGRect {
        guard let layer else { return .zero }
        let meta = vnRectToMetadata(vnRect)
        return layer.layerRectConverted(fromMetadataOutputRect: meta)
    }

    private func convertVisionPoint(_ vnPoint: CGPoint,
                                    layer: AVCaptureVideoPreviewLayer?) -> CGPoint {
        guard let layer else { return .zero }
        let meta = vnPointToMetadata(vnPoint)
        return layer.layerPointConverted(fromCaptureDevicePoint: meta)
    }

    private func convertVisionRectangleToPath(_ rect: VNRectangleObservation,
                                              layer: AVCaptureVideoPreviewLayer?) -> Path {
        guard let layer else { return Path() }
        
        // Convert each corner point properly
//        let tl = convertVisionPoint(rect.bottomRight, layer: layer)
//        let tr = convertVisionPoint(rect.bottomLeft, layer: layer)
//        let br = convertVisionPoint(rect.topLeft, layer: layer)
//        let bl = convertVisionPoint(rect.topRight, layer: layer)
        
        let tl = convertVisionPoint(rect.topRight, layer: layer)
        let tr = convertVisionPoint(rect.bottomRight, layer: layer)
        let br = convertVisionPoint(rect.bottomLeft, layer: layer)
        let bl = convertVisionPoint(rect.topLeft, layer: layer)

        var path = Path()
        path.move(to: tl)
        path.addLine(to: tr)
        path.addLine(to: br)
        path.addLine(to: bl)
        path.closeSubpath()
        return path
    }

    @ViewBuilder
    private func dot(_ color: Color, at p: CGPoint) -> some View {
        if p != .zero {
            Circle().fill(color).frame(width: 8, height: 8).position(p)
        }
    }
}
