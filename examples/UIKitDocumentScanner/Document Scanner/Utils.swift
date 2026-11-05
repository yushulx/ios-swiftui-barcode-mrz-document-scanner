//
//  Utils.swift
//  Document Scanner
//
//  Created by xulihang on 2022/11/28.
//

import Foundation
import UIKit


class Utils {
    static func scalePoints(_ points:[CGPoint], xPercent:Double, yPercent:Double) -> [CGPoint]{
        var newPoints:[CGPoint] = []
        for point in points {
            let x = point.x * xPercent
            let y = point.y * yPercent
            let newPoint = CGPoint(x: x, y: y)
            newPoints.append(newPoint)
        }
        return newPoints
    }
    
    static func scaleAndRotatePoints(_ points:[CGPoint], frameWidth:Double, frameHeight:Double,viewWidth:Double, viewHeight:Double) -> [CGPoint]{
        var newPoints:[CGPoint] = []
        for point in points {
            var x = point.x
            var y = point.y

            let orientation = UIDevice.current.orientation
            if  orientation == .portrait || orientation == .unknown || orientation == .faceUp {
                x = frameHeight - point.y;
                y = point.x;
            } else if orientation == .landscapeRight {
                x = frameWidth - point.x;
                y = frameHeight - point.y;
            }

            x = x * xPercent(frameWidth:frameWidth,frameHeight:frameHeight,viewWidth:viewWidth,viewHeight:viewHeight)
            y = y * yPercent(frameWidth:frameWidth,frameHeight:frameHeight,viewWidth:viewWidth,viewHeight:viewHeight)
            let newPoint = CGPoint(x: x, y: y)
            newPoints.append(newPoint)
        }
        return newPoints
    }
    
    static func xPercent(frameWidth:Double, frameHeight:Double,viewWidth:Double, viewHeight:Double) -> Double {
        if (frameWidth>frameHeight && viewWidth>viewHeight) {
            return viewWidth/frameWidth
        }else{
            return viewWidth/frameHeight
        }
    }
    
    static func yPercent(frameWidth:Double, frameHeight:Double,viewWidth:Double, viewHeight:Double) -> Double {
        if (frameWidth>frameHeight && viewWidth>viewHeight) {
            return viewHeight/frameHeight
        }else{
            return viewHeight/frameWidth
        }
    }
    
    static func intersectionOverUnion(pts1:[CGPoint] ,pts2:[CGPoint]) -> Double {
        let rect1 = getRectFromPoints(points:pts1);
        let rect2 = getRectFromPoints(points:pts2);
        return rectIntersectionOverUnion(rect1:rect1, rect2:rect2);
    }

    static func rectIntersectionOverUnion(rect1:CGRect, rect2:CGRect) -> Double {
        let leftColumnMax = max(rect1.minX, rect2.minX);
        let rightColumnMin = min(rect1.maxX,rect2.maxX);
        let upRowMax = max(rect1.minY, rect2.minY);
        let downRowMin = min(rect1.maxY,rect2.maxY);

        if (leftColumnMax>=rightColumnMin || downRowMin<=upRowMax){
          return 0;
        }

        let s1 = rect1.width*rect1.height;
        let s2 = rect2.width*rect2.height;
        let sCross = (downRowMin-upRowMax)*(rightColumnMin-leftColumnMax);
        return sCross/(s1+s2-sCross);
    }

    static func getRectFromPoints(points:[CGPoint]) -> CGRect {
        var minX,minY,maxX,maxY:CGFloat

        minX = points[0].x
        minY = points[0].y
        maxX = 0
        maxY = 0

        for point in points {
            minX = min(point.x,minX)
            minY = min(point.y,minY)
            maxX = max(point.x,maxX)
            maxY = max(point.y,maxY)
        }
        
        let r = CGRect(x: minX, y: minY, width: maxX-minX, height: maxY-minY)
        return r
    }
    
    static func normalizedImage(_ image:UIImage) -> UIImage {
        if image.imageOrientation == UIImage.Orientation.up {
            return image
        }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(x:0,y:0,width:image.size.width,height:image.size.height))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext();
        return normalized
    }
}
