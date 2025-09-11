import SwiftUI
import AVFoundation
import Vision

struct OverlayView: View {
    let faces: [VNFaceObservation]
    let rectangles: [VNRectangleObservation]
    let mrzContour: [CGPoint]
    let previewLayer: AVCaptureVideoPreviewLayer?
    let imageWidth: Int
    let imageHeight: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Faces
                ForEach(Array(faces.enumerated()), id: \.offset) { idx, face in
                    let r = convertVisionRect(face.boundingBox, layer: previewLayer)
                    if r != .zero {
                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: r.width, height: r.height)
                            .position(x: r.midX, y: geometry.size.height - r.midY + getYOffset())
                        Text("Face \(idx)")
                            .font(.caption2).bold()
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                            .position(x: r.midX, y: geometry.size.height - max(r.minY - 12, 10) + getYOffset())
                    }
                }

                // Rectangles
                ForEach(Array(rectangles.enumerated()), id: \.offset) { idx, ro in
                    let path = convertVisionRectangleToPath(ro, layer: previewLayer, screenSize: geometry.size)
                    path.stroke(Color.blue, lineWidth: 3)

                    let bboxL = convertVisionRect(ro.boundingBox, layer: previewLayer)
                    if bboxL != .zero {
                        Text("Document \(idx)")
                            .font(.caption2).bold()
                            .padding(4)
                            .background(Color.white.opacity(0.85))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                            .position(x: bboxL.midX, y: geometry.size.height - max(bboxL.minY - 12, 10) + getYOffset())

                        // Corner dots
                        let tl = convertVisionPoint(ro.topLeft, layer: previewLayer, screenSize: geometry.size)
                        let tr = convertVisionPoint(ro.topRight, layer: previewLayer, screenSize: geometry.size)
                        let br = convertVisionPoint(ro.bottomRight, layer: previewLayer, screenSize: geometry.size)
                        let bl = convertVisionPoint(ro.bottomLeft, layer: previewLayer, screenSize: geometry.size)
                        Group {
                            dot(.red, at: tl)
                            dot(.green, at: tr)
                            dot(.yellow, at: br)
                            dot(.orange, at: bl)
                        }
                    }
                }
                
                // MRZ Contour
                if !mrzContour.isEmpty && imageWidth > 0 && imageHeight > 0 {
                    let mrzPath = convertMRZContourToPath(
                        mrzContour, 
                        screenSize: geometry.size,
                        imageWidth: imageWidth,
                        imageHeight: imageHeight
                    )
                    mrzPath.stroke(Color.orange, lineWidth: 2)
                    
                    if mrzContour.count >= 4 {
                        Text("MRZ")
                            .font(.caption2).bold()
                            .padding(4)
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .position(x: geometry.size.width / 2, y: 50)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func getYOffset() -> CGFloat {
        guard let layer = previewLayer else { return 0 }
                
        // Calculate the vertical crop offset
        // When videoGravity is .resizeAspectFill, the layer might be larger than the screen
        let layerHeight = layer.frame.height
        let screenHeight: CGFloat = 770 // Your screen height
        let yOffset = layerHeight - screenHeight
        
        return yOffset
    }

    // MARK: - Helpers (VN -> metadata -> layer)

    @inline(__always)
    private func vnRectToMetadata(_ r: CGRect) -> CGRect {
        return r
    }

    @inline(__always)
    private func vnPointToMetadata(_ p: CGPoint) -> CGPoint {
        return p
    }

    private func convertVisionRect(_ vnRect: CGRect,
                                   layer: AVCaptureVideoPreviewLayer?) -> CGRect {
        guard let layer else { return .zero }
        let meta = vnRectToMetadata(vnRect)
        return layer.layerRectConverted(fromMetadataOutputRect: meta)
    }

    private func convertVisionPoint(_ vnPoint: CGPoint,
                                    layer: AVCaptureVideoPreviewLayer?,
                                    screenSize: CGSize) -> CGPoint {
        guard let layer else { return .zero }
        let meta = vnPointToMetadata(vnPoint)
        let rect = CGRect(origin: meta, size: .zero)
        let convertedRect = layer.layerRectConverted(fromMetadataOutputRect: rect)
        
        // Flip Y coordinate and add the preview layer's Y offset
        return CGPoint(
            x: convertedRect.origin.x,
            y: screenSize.height - convertedRect.origin.y + getYOffset()
        )
    }

    private func convertVisionRectangleToPath(_ rect: VNRectangleObservation,
                                              layer: AVCaptureVideoPreviewLayer?,
                                              screenSize: CGSize) -> Path {
        guard let layer else { return Path() }
        
        // Convert each corner point and flip Y coordinates
        let tl = convertVisionPoint(rect.topLeft, layer: layer, screenSize: screenSize)
        let tr = convertVisionPoint(rect.topRight, layer: layer, screenSize: screenSize)
        let br = convertVisionPoint(rect.bottomRight, layer: layer, screenSize: screenSize)
        let bl = convertVisionPoint(rect.bottomLeft, layer: layer, screenSize: screenSize)

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
    
    private func convertMRZContourToPath(_ contour: [CGPoint], screenSize: CGSize, imageWidth: Int, imageHeight: Int) -> Path {
        guard contour.count >= 4 else { return Path() }
        
        var path = Path()
        
        // Convert the first point
        let firstPoint = convertMRZPoint(contour[0], screenSize: screenSize, imageWidth: imageWidth, imageHeight: imageHeight)
        path.move(to: firstPoint)
        
        // Add lines to remaining points
        for i in 1..<contour.count {
            let point = convertMRZPoint(contour[i], screenSize: screenSize, imageWidth: imageWidth, imageHeight: imageHeight)
            path.addLine(to: point)
        }
        
        // Close the path
        path.closeSubpath()
        return path
    }
    
    private func convertMRZPoint(_ point: CGPoint, screenSize: CGSize, imageWidth: Int, imageHeight: Int) -> CGPoint {
        guard let previewLayer = previewLayer, imageWidth > 0, imageHeight > 0 else { 
            return .zero 
        }
        
        // MRZ coordinates from Dynamsoft are in camera pixel coordinates
        // We need to account for the camera orientation (landscape) vs screen orientation (portrait)
        
        // For portrait mode with back camera, the image is rotated 90 degrees
        // So we need to transform coordinates: (x,y) -> (height-y, x)
        let rotatedX = CGFloat(imageHeight) - point.y
        let rotatedY = point.x
        
        // Now normalize to [0,1] range like Vision framework
        let normalizedX = rotatedX / CGFloat(imageHeight)
        let normalizedY = rotatedY / CGFloat(imageWidth)
        
        // Create a normalized point (like Vision framework coordinates)
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Convert using the preview layer's coordinate conversion method
        let rect = CGRect(origin: normalizedPoint, size: .zero)
        let convertedRect = previewLayer.layerRectConverted(fromMetadataOutputRect: rect)
        
        // Apply the same Y-flipping and offset adjustments as other Vision-based conversions
        return CGPoint(
            x: convertedRect.origin.x,
            y: screenSize.height - convertedRect.origin.y + getYOffset()
        )
    }
}
