import SwiftUI

#if os(iOS)
    import UIKit
    import AVFoundation
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
    #if os(iOS)
        var videoOrientation: AVCaptureVideoOrientation = .portrait
    #endif

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
            #if os(iOS)
                let convertedPoints = points.map { point -> CGPoint in
                    let x = CGFloat(point["x"]!.doubleValue)
                    let y = CGFloat(point["y"]!.doubleValue)
                    return convertToOverlayCoordinates(
                        cameraPoint: CGPoint(x: x, y: y),
                        overlaySize: overlaySize,
                        orientation: videoOrientation
                    )
                }
            #elseif os(macOS)
                let convertedPoints = points.map { point -> CGPoint in
                    let x = CGFloat(point["x"]!.doubleValue)
                    let y = CGFloat(point["y"]!.doubleValue)
                    return convertToOverlayCoordinates(
                        cameraPoint: CGPoint(x: x, y: y), overlaySize: overlaySize)
                }
            #endif

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

    #if os(iOS)
        private func convertToOverlayCoordinates(
            cameraPoint: CGPoint, overlaySize: CGSize, orientation: AVCaptureVideoOrientation
        ) -> CGPoint {
            let cameraSize = cameraPreviewSize

            // Calculate scaling factors
            let scaleX = overlaySize.width / cameraSize.height
            let scaleY = overlaySize.height / cameraSize.width

            // Apply scaling factors
            var transformedPoint = CGPoint.zero

            if scaleX < scaleY {
                let deltaX = CGFloat((cameraSize.height * scaleY - overlaySize.width) / 2)

                transformedPoint = CGPoint(
                    x: cameraPoint.x * scaleY, y: cameraPoint.y * scaleY)

                transformedPoint = CGPoint(
                    x: overlaySize.width - transformedPoint.y + deltaX, y: transformedPoint.x)

            } else {
                let deltaY = CGFloat((cameraSize.width * scaleX - overlaySize.height) / 2)
                transformedPoint = CGPoint(
                    x: cameraPoint.x * scaleX, y: cameraPoint.y * scaleX)

                transformedPoint = CGPoint(
                    x: overlaySize.width - transformedPoint.y, y: transformedPoint.x - deltaY)
            }

            return transformedPoint

        }
    #elseif os(macOS)
        private func convertToOverlayCoordinates(cameraPoint: CGPoint, overlaySize: CGSize)
            -> CGPoint
        {
            let cameraSize = cameraPreviewSize

            // Calculate scaling factors
            let scaleX = overlaySize.width / cameraSize.width
            let scaleY = overlaySize.height / cameraSize.height

            if scaleX < scaleY {
                let deltaX = CGFloat((cameraSize.width * scaleY - overlaySize.width) / 2)
                return CGPoint(x: cameraPoint.x * scaleY - deltaX, y: cameraPoint.y * scaleY)
            } else {
                let deltaY = CGFloat((cameraSize.height * scaleX - overlaySize.height) / 2)
                return CGPoint(x: cameraPoint.x * scaleX, y: cameraPoint.y * scaleX - deltaY)
            }
        }
    #endif
}
