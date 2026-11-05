//
//  CroppingController.swift
//  Document Scanner
//
//  Created by xulihang on 2022/11/27.
//

import UIKit
import DynamsoftCaptureVisionBundle

class CroppingController: UIViewController {
    var imageView: UIImageView!
    var image:UIImage!
    var overlay: Overlay!
    var toolbar:UIToolbar!
    var cvr:CaptureVisionRouter!
    var points:[CGPoint]!
    var vertices:[Vertice] = []
    var selectedVertice:Vertice!
    var touchedX = -1.0
    var touchedY = -1.0
    var initialVerticeX = -1.0
    var initialVerticeY = -1.0
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.image = Utils.normalizedImage(self.image)
        self.imageView = UIImageView(frame: .zero)
        self.imageView.image = self.image
        self.overlay = Overlay()
        self.toolbar = UIToolbar.init()
        let retakeButton = UIBarButtonItem.init(title: "Retake", style: .plain, target: self, action: #selector(retakeAction))
        let okayButton =  UIBarButtonItem.init(title: "Okay", style: .plain, target: self, action: #selector(okayAction))
        let flexibleSpace = UIBarButtonItem.flexibleSpace()
        self.toolbar.items = [retakeButton,flexibleSpace,okayButton]
        
        self.view.addSubview(self.imageView)
        self.view.addSubview(self.overlay)
        self.view.addSubview(self.toolbar)
        
        let tapGesture = UITapGestureRecognizer(target: self, action:  #selector (self.tapAction (_:)))
        self.view.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action:  #selector (self.panAction (_:)))
        
        self.view.addGestureRecognizer(panGesture)
        detect()
    }
    
    @objc func tapAction(_ sender:UITapGestureRecognizer){
        // do other task
        print("tap gesture")
        print(sender.view?.description)
    }
    
    @objc func tapActionForVertice(_ sender:UITapGestureRecognizer){
        print("vertice tap gesture")
        self.selectedVertice = sender.view as! Vertice
        for vertice in vertices {
            if self.selectedVertice == vertice {
                vertice.lineWidth = 5
            }else{
                vertice.lineWidth = 3
            }
            vertice.setNeedsDisplay()
        }
    }
    
    
    
    @objc func panAction(_ sender:UIPanGestureRecognizer){
        // do other task
        print("pan gesture")
        
        if selectedVertice != nil {
            let point = sender.location(in: self.view)
            let translation = sender.translation(in: self.view)
            let pTouchedX = point.x - translation.x
            let pTouchedY = point.y - translation.y
            if pTouchedX != self.touchedX || pTouchedY != self.touchedY {
                self.touchedX = pTouchedX
                self.touchedY = pTouchedY
                self.initialVerticeX = selectedVertice.frame.minX
                self.initialVerticeY = selectedVertice.frame.minY
            }
            var x = self.initialVerticeX + translation.x
            var y = self.initialVerticeY + translation.y
            let width = selectedVertice.frame.width
            let height = selectedVertice.frame.height
            selectedVertice.frame = CGRect.init(x: x, y: y, width: width, height: height)
            let selectedIndex = vertices.firstIndex(of: selectedVertice)!
            x = x - getOffsetX(index: selectedIndex, size: 24)
            y = y - getOffsetY(index: selectedIndex, size: 24)
            updatePoints(newX:x,newY:y)
        }
    }
    
    func updatePoints(newX:Double,newY:Double) {
        if selectedVertice != nil {
            let selectedIndex = vertices.firstIndex(of: selectedVertice)!
            var point = self.points[selectedIndex]
            let xPercent = self.view.frame.width/self.image.size.width
            let yPercent = self.view.frame.height/self.image.size.height
            point.x = newX/xPercent
            point.y = newY/yPercent
            self.points[selectedIndex] = point
            var pointForView = self.overlay.points[selectedIndex]
            pointForView.x = newX
            pointForView.y = newY
            self.overlay.points[selectedIndex] = pointForView
            self.overlay.setNeedsDisplay()
            
        }
    }
    
    func detect(){
        if let cvr = self.cvr {
            let capturedResult = cvr.captureFromImage(self.image,templateName: "DetectDocumentBoundaries_Default")
            // 3.x returns document results through processedDocumentResult.
            if let result = capturedResult.processedDocumentResult?.detectedQuadResultItems?.first {
                self.points = result.location.points.map { $0.cgPointValue }
                let CGPoints = Utils.scalePoints(self.points, xPercent: self.view.frame.width/self.image.size.width, yPercent: self.view.frame.height/self.image.size.height)
                showVertices(CGPoints)
                self.overlay.points = CGPoints
                self.overlay.setNeedsDisplay()
            }
        }
    }
    
    func showVertices(_ CGPoints:[CGPoint]){
        let verticeSize = 24.0
        var index = 0
        for point in CGPoints {
            let vertice = Vertice()
            self.view.addSubview(vertice)
            let tapGesture = UITapGestureRecognizer(target: self, action:  #selector (self.tapActionForVertice (_:)))
            vertice.addGestureRecognizer(tapGesture)
            vertice.backgroundColor = UIColor.init(red: 255, green: 0, blue: 0, alpha: 0.5)
            let x = point.x + getOffsetX(index: index, size: verticeSize)
            let y = point.y + getOffsetY(index: index, size: verticeSize)
            vertice.frame = CGRect.init(x: x, y: y, width: verticeSize, height: verticeSize)
            vertices.append(vertice)
            index = index + 1
        }
    }
    
    func getOffsetX(index:Int, size:Double) -> Double {
        if index == 0 {
            return -size
        }else if index == 1 {
            return 0
        }else if index == 2 {
            return 0
        }else {
            return -size
        }
    }
    
    func getOffsetY(index:Int, size:Double) -> Double {
        if index == 0 {
            return -size
        }else if index == 1 {
            return -size
        }else if index == 2 {
            return 0
        }else {
            return 0
        }
    }
    
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let imageView = self.imageView {
            let width: CGFloat = view.frame.width
            let height: CGFloat = view.frame.height
            let x: CGFloat = 0.0
            let y: CGFloat = 0.0
            imageView.frame = CGRect.init(x: x, y: y, width: width, height: height)
        }
        if let overlay = self.overlay {
            let width: CGFloat = view.frame.width
            let height: CGFloat = view.frame.height
            let x: CGFloat = 0.0
            let y: CGFloat = 0.0
            overlay.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0)
            overlay.frame = CGRect.init(x: x, y: y, width: width, height: height)
        }
        if let toolbar = self.toolbar {
            let width: CGFloat = view.frame.width
            let height: CGFloat = 32
            let x: CGFloat = 0.0
            let y: CGFloat = view.frame.height - 32
            toolbar.frame = CGRect.init(x: x, y: y, width: width, height: height)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }

    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
        self.navigationController?.navigationBar.isHidden = false
    }
    
    @objc
    func retakeAction() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc
    func okayAction() {
        let vc = ResultViewerController()
        vc.points = self.points
        vc.cvr = self.cvr
        vc.image = self.image
        self.navigationController?.pushViewController(vc, animated:true)
    }
    
}

