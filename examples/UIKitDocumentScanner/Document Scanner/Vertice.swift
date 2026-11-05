//
//  Vertice.swift
//  Document Scanner
//
//  Created by xulihang on 2022/11/30.
//

import UIKit
class Vertice: UIView {
    var lineWidth = 3.0
    override func draw(_ rect: CGRect) {
        let h = rect.height
        let w = rect.width
        let color:UIColor = UIColor.red
        let drect = CGRect(x: 0, y: 0, width: w, height: h)
        let bpath:UIBezierPath = UIBezierPath(rect: drect)
        color.set()
        bpath.lineWidth = lineWidth
        bpath.stroke()
    }
}
