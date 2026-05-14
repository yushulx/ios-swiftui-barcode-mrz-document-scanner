import CoreGraphics
import DynamsoftCaptureVisionBundle

func cloneQuadrilateral(_ quad: Quadrilateral?) -> Quadrilateral? {
    guard let quad else { return nil }
    return Quadrilateral(pointArray: quad.points)
}

func quadrilateralPoints(_ quad: Quadrilateral) -> [CGPoint] {
    quad.points.map { $0.cgPointValue }
}

func quadrilateralIoU(_ lhs: Quadrilateral, _ rhs: Quadrilateral) -> Double {
    let a = quadrilateralBounds(lhs)
    let b = quadrilateralBounds(rhs)

    let intersection = a.intersection(b)
    guard !intersection.isNull && intersection.width > 0 && intersection.height > 0 else {
        return 0
    }

    let intersectionArea = intersection.width * intersection.height
    let unionArea = (a.width * a.height) + (b.width * b.height) - intersectionArea
    guard unionArea > 0 else { return 0 }
    return intersectionArea / unionArea
}

func quadrilateralBounds(_ quad: Quadrilateral) -> CGRect {
    let points = quadrilateralPoints(quad)
    guard let first = points.first else { return .zero }

    var minX = first.x
    var minY = first.y
    var maxX = first.x
    var maxY = first.y

    for point in points {
        minX = min(minX, point.x)
        minY = min(minY, point.y)
        maxX = max(maxX, point.x)
        maxY = max(maxY, point.y)
    }

    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

func quadrilateralArea(_ quad: Quadrilateral) -> Double {
    let points = quadrilateralPoints(quad)
    guard points.count >= 4 else { return 0 }

    var area: Double = 0
    for index in points.indices {
        let nextIndex = (index + 1) % points.count
        area += Double(points[index].x * points[nextIndex].y)
        area -= Double(points[nextIndex].x * points[index].y)
    }
    return abs(area) / 2
}