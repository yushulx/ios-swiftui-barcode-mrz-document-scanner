import UIKit

extension UIImage {
    func normalizedOrientationImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }

    func rotated(quarterTurns: Int) -> UIImage {
        let normalizedQuarterTurns = ((quarterTurns % 4) + 4) % 4
        guard normalizedQuarterTurns != 0 else { return self }

        let angle = CGFloat(normalizedQuarterTurns) * (.pi / 2)
        let rotatedSize = normalizedQuarterTurns.isMultiple(of: 2) ? size : CGSize(width: size.height, height: size.width)

        let renderer = UIGraphicsImageRenderer(size: rotatedSize)
        return renderer.image { context in
            context.cgContext.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            context.cgContext.rotate(by: angle)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    func processed(for mode: DocumentColorMode) -> UIImage {
        switch mode {
        case .color:
            return self
        case .grayscale:
            return pixelProcessed(binary: false)
        case .binary:
            return pixelProcessed(binary: true)
        }
    }

    private func pixelProcessed(binary: Bool) -> UIImage {
        guard let cgImage else { return self }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return self
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Double(pixels[offset])
            let green = Double(pixels[offset + 1])
            let blue = Double(pixels[offset + 2])
            let gray = UInt8(max(0, min(255, Int((0.299 * red) + (0.587 * green) + (0.114 * blue)))))
            let value = binary ? (gray > 128 ? UInt8(255) : UInt8(0)) : gray
            pixels[offset] = value
            pixels[offset + 1] = value
            pixels[offset + 2] = value
        }

        guard let outputImage = context.makeImage() else { return self }
        return UIImage(cgImage: outputImage, scale: scale, orientation: .up)
    }
}