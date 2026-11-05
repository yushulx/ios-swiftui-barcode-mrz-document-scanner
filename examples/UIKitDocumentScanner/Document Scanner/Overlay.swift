//
//  Overlay.swift
//  Document Scanner
//
//  Created by xulihang on 2022/11/28.
//

import UIKit
import DynamsoftCaptureVisionBundle

class Overlay: UIView {
    var points:[CGPoint] = []
    override func draw(_ rect: CGRect) {
        print("draw")
        print(points.count)
        if points.count == 4 {
            let aPath = UIBezierPath()
            aPath.move(to: points[0])
            aPath.addLine(to: points[1])
            aPath.move(to: points[1])
            aPath.addLine(to: points[2])
            aPath.move(to: points[2])
            aPath.addLine(to: points[3])
            aPath.move(to: points[3])
            aPath.addLine(to: points[0])

            // Keep using the method addLine until you get to the one where about to close the path
            aPath.close()

            // If you want to stroke it with a red color
            UIColor.red.set()
            aPath.lineWidth = 3
            aPath.stroke()
        }
    }
}
