import Foundation
import UIKit
import DynamsoftCaptureVisionBundle

let detectAndNormalizeTemplateName = "DetectAndNormalizeDocument_Default"
let ddnDrawingLayerId: UInt = 1

enum ScannerRoute {
    case scanner
    case results
    case sort
}

enum DocumentColorMode: String, CaseIterable, Identifiable {
    case color
    case grayscale
    case binary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .color:
            return "Color"
        case .grayscale:
            return "Gray"
        case .binary:
            return "B&W"
        }
    }
}

struct AutoCaptureSettings: Equatable {
    private enum Key {
        static let iouThreshold = "quad_stabilizer_iou_threshold"
        static let areaDeltaThreshold = "quad_stabilizer_area_delta_threshold"
        static let stableFrameCount = "quad_stabilizer_stable_frame_count"
        static let autoCaptureEnabled = "quad_stabilizer_auto_capture_enabled"
    }

    var iouThreshold: Double = 0.85
    var areaDeltaThreshold: Double = 0.15
    var stableFrameCount: Int = 3
    var autoCaptureEnabled: Bool = true

    static func load() -> AutoCaptureSettings {
        let defaults = UserDefaults.standard
        var settings = AutoCaptureSettings()

        if defaults.object(forKey: Key.iouThreshold) != nil {
            settings.iouThreshold = defaults.double(forKey: Key.iouThreshold)
        }
        if defaults.object(forKey: Key.areaDeltaThreshold) != nil {
            settings.areaDeltaThreshold = defaults.double(forKey: Key.areaDeltaThreshold)
        }
        if defaults.object(forKey: Key.stableFrameCount) != nil {
            settings.stableFrameCount = defaults.integer(forKey: Key.stableFrameCount)
        }
        if defaults.object(forKey: Key.autoCaptureEnabled) != nil {
            settings.autoCaptureEnabled = defaults.bool(forKey: Key.autoCaptureEnabled)
        }

        settings.stableFrameCount = max(1, settings.stableFrameCount)
        return settings
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(iouThreshold, forKey: Key.iouThreshold)
        defaults.set(areaDeltaThreshold, forKey: Key.areaDeltaThreshold)
        defaults.set(stableFrameCount, forKey: Key.stableFrameCount)
        defaults.set(autoCaptureEnabled, forKey: Key.autoCaptureEnabled)
    }
}

struct ScannedPage: Identifiable {
    let id = UUID()
    var originalImageData: ImageData?
    var normalizedImageData: ImageData?
    var quad: Quadrilateral?
    var fallbackImage: UIImage?
    var colorMode: DocumentColorMode = .color
    var rotationQuarterTurns: Int = 0

    var canEdit: Bool {
        originalImageData != nil && quad != nil
    }

    func renderedImage(processor: ImageProcessor = ImageProcessor()) -> UIImage? {
        let rendered: UIImage?

        if let normalizedImageData {
            var workingImage = normalizedImageData
            switch colorMode {
            case .color:
                break
            case .grayscale:
                workingImage = processor.convert(toGray: workingImage)
            case .binary:
                let grayscaleImage = processor.convert(toGray: workingImage)
                workingImage = processor.convert(toBinaryLocal: grayscaleImage)
            }
            rendered = try? workingImage.toUIImage()
        } else if let fallbackImage {
            rendered = fallbackImage.processed(for: colorMode)
        } else {
            rendered = nil
        }

        return rendered?.rotated(quarterTurns: rotationQuarterTurns)
    }
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct EditorTarget: Identifiable {
    let id: UUID
}