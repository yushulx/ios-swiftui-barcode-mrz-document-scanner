import SwiftUI

#if os(iOS)
    import UIKit
    typealias OverlayView = UIView
    typealias OverlayColor = UIColor
#elseif os(macOS)
    import Cocoa
    typealias OverlayView = NSView
    typealias OverlayColor = NSColor
#endif

class BarcodeOverlayView: OverlayView {
    var barcodeData: [[String: Any]] = []  // Array of barcode data to be drawn
    var cameraPreviewSize: CGSize = .zero

    override func draw(_ rect: CGRect) {
        guard cameraPreviewSize != .zero else { return }

        #if os(iOS)
            guard let context = UIGraphicsGetCurrentContext() else { return }
        #elseif os(macOS)
            guard let context = NSGraphicsContext.current?.cgContext else { return }
        #endif

        let overlaySize = bounds.size

        for barcode in barcodeData {
            guard let points = barcode["points"] as? [[String: NSNumber]],
                let format = barcode["format"] as? String,
                let text = barcode["text"] as? String
            else { continue }

            // Convert points from camera space to overlay space
            let convertedPoints = points.map { point -> CGPoint in
                let x = CGFloat(point["x"]!.doubleValue)
                let y = CGFloat(point["y"]!.doubleValue)
                return convertToOverlayCoordinates(
                    cameraPoint: CGPoint(x: x, y: y), overlaySize: overlaySize)
            }

            // Draw the polygon
            context.setStrokeColor(OverlayColor.red.cgColor)
            context.setLineWidth(2.0)

            if let firstPoint = convertedPoints.first {
                context.beginPath()
                context.move(to: firstPoint)
                for point in convertedPoints.dropFirst() {
                    context.addLine(to: point)
                }
                context.closePath()
                context.strokePath()
            }

            // Draw the text
            let labelRect = CGRect(
                x: convertedPoints[0].x,
                y: convertedPoints[0].y - 20,
                width: 200,
                height: 20
            )
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            #if os(iOS)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: OverlayColor.yellow,
                    .paragraphStyle: paragraphStyle,
                ]
            #elseif os(macOS)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: OverlayColor.yellow,
                    .paragraphStyle: paragraphStyle,
                ]
            #endif

            let attributedText = NSAttributedString(
                string: "\(format): \(text)", attributes: attributes)
            attributedText.draw(in: labelRect)
        }
    }

    private func convertToOverlayCoordinates(cameraPoint: CGPoint, overlaySize: CGSize) -> CGPoint {
        let cameraSize = cameraPreviewSize

        // Calculate scaling factors
        let scaleX = overlaySize.width / cameraSize.width
        let scaleY = overlaySize.height / cameraSize.height

        // Apply scaling factors to convert coordinates
        return CGPoint(x: cameraPoint.x * scaleX, y: cameraPoint.y * scaleY)
    }
}
