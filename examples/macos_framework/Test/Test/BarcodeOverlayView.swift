import Cocoa
import SwiftUI

typealias OverlayView = NSView
typealias OverlayColor = NSColor

class BarcodeOverlayView: OverlayView {
    var barcodeData: [[String: Any]] = []  // Array of barcode data to be drawn
    var cameraPreviewSize: CGSize = .zero

    func wrapResults(results: [[String: Any]]) -> NSArray {
        let outResults = NSMutableArray()

        for barcode in results {
            let subDic = NSMutableDictionary()

            // Safely extract required values with optional binding
            guard
                let points = barcode["points"] as? [[String: NSNumber]],
                let format = barcode["format"] as? String,
                let text = barcode["text"] as? String,
                let angle = barcode["angle"] as? Int,
                let barcodeBytes = barcode["barcodeBytes"] as? Data
            else {
                continue
            }

            // Add extracted values to the dictionary
            subDic.setObject(format, forKey: "format" as NSCopying)
            subDic.setObject(text, forKey: "text" as NSCopying)
            subDic.setObject(angle, forKey: "angle" as NSCopying)
            subDic.setObject(barcodeBytes, forKey: "barcodeBytes" as NSCopying)

            // Safely extract points
            if points.count >= 4 {
                subDic.setObject(points[0]["x"]?.intValue ?? 0, forKey: "x1" as NSCopying)
                subDic.setObject(points[0]["y"]?.intValue ?? 0, forKey: "y1" as NSCopying)
                subDic.setObject(points[1]["x"]?.intValue ?? 0, forKey: "x2" as NSCopying)
                subDic.setObject(points[1]["y"]?.intValue ?? 0, forKey: "y2" as NSCopying)
                subDic.setObject(points[2]["x"]?.intValue ?? 0, forKey: "x3" as NSCopying)
                subDic.setObject(points[2]["y"]?.intValue ?? 0, forKey: "y3" as NSCopying)
                subDic.setObject(points[3]["x"]?.intValue ?? 0, forKey: "x4" as NSCopying)
                subDic.setObject(points[3]["y"]?.intValue ?? 0, forKey: "y4" as NSCopying)
            }

            outResults.add(subDic)
        }

        return outResults
    }

    override func draw(_ rect: CGRect) {
        guard cameraPreviewSize != .zero else { return }

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let overlaySize = bounds.size

//        let res = wrapResults(results: barcodeData)
        for barcode in barcodeData {
            guard let points = barcode["points"] as? [[String: NSNumber]],
                let format = barcode["format"] as? String,
                let text = barcode["text"] as? String
            else { continue }

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

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: OverlayColor.yellow,
                .paragraphStyle: paragraphStyle,
            ]

            let attributedText = NSAttributedString(
                string: "\(format): \(text)", attributes: attributes)
            attributedText.draw(in: labelRect)
        }
    }

    private func convertToOverlayCoordinates(cameraPoint: CGPoint, overlaySize: CGSize)
        -> CGPoint
    {
        let cameraSize = cameraPreviewSize

        // Calculate scaling factors
        let scaleX = overlaySize.width / cameraSize.width
        let scaleY = overlaySize.height / cameraSize.height

        if scaleX < scaleY {
            let deltaX = CGFloat((cameraSize.width * scaleY - overlaySize.width) / 2)
            return CGPoint(x: cameraPoint.x * scaleY - deltaX, y: (cameraSize.height - cameraPoint.y) * scaleY)
        } else {
            let deltaY = CGFloat((cameraSize.height * scaleX - overlaySize.height) / 2)
            return CGPoint(x: cameraPoint.x * scaleX, y: (cameraSize.height - cameraPoint.y) * scaleX - deltaY)
        }
    }
}
