import Foundation
import DynamsoftCaptureVisionBundle

final class QuadStabilizer {
    var settings: AutoCaptureSettings

    private var previousQuad: Quadrilateral?
    private var consecutiveStableFrames = 0

    init(settings: AutoCaptureSettings) {
        self.settings = settings
    }

    func reset() {
        previousQuad = nil
        consecutiveStableFrames = 0
    }

    func feed(_ quad: Quadrilateral) -> Bool {
        guard settings.autoCaptureEnabled else { return false }

        guard let previousQuad else {
            self.previousQuad = cloneQuadrilateral(quad)
            consecutiveStableFrames = 0
            return false
        }

        let iou = quadrilateralIoU(previousQuad, quad)
        let previousArea = quadrilateralArea(previousQuad)
        let currentArea = quadrilateralArea(quad)
        let areaDelta = previousArea > 0 ? abs(currentArea - previousArea) / previousArea : 1

        if iou >= settings.iouThreshold && areaDelta <= settings.areaDeltaThreshold {
            consecutiveStableFrames += 1
            if consecutiveStableFrames >= settings.stableFrameCount {
                reset()
                return true
            }
        } else {
            consecutiveStableFrames = 0
        }

        self.previousQuad = cloneQuadrilateral(quad)
        return false
    }
}