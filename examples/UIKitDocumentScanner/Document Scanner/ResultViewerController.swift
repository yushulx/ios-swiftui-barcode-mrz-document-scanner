//
//  ResultViewerController.swift
//  Document Scanner
//
//  Created by xulihang on 2022/11/27.
//

import UIKit
import DynamsoftCaptureVisionBundle

class ResultViewerController: UIViewController {
    var imageView: UIImageView!
    var image: UIImage!
    var cvr:CaptureVisionRouter!
    var points:[CGPoint]!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.white
        self.imageView = UIImageView(frame: .zero)
        self.imageView.contentMode = UIView.ContentMode.scaleAspectFit
        self.view.addSubview(self.imageView)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save",
                                                                 style: .plain,
                                                                 target: self,
                                                                 action: #selector(saveAction))
        normalize()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    func normalize(){
        let quad = Quadrilateral(pointArray: points.map { NSValue(cgPoint: $0) })
        let settings = try? cvr.getSimplifiedSettings("NormalizeDocument_Binary")
        settings?.roi = quad
        settings?.roiMeasuredInPercentage = false
        try? cvr.updateSettings("NormalizeDocument_Binary", settings: settings!)
        let capturedResult = cvr.captureFromImage(self.image, templateName: "NormalizeDocument_Binary")
        if let deskewedItem = capturedResult.processedDocumentResult?.deskewedImageResultItems?.first,
           let imageData = deskewedItem.imageData {
            self.imageView.image = try? imageData.toUIImage()
        }
        
        
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let imageView = self.imageView {
            let width: CGFloat = self.view.frame.width
            let height: CGFloat = self.view.frame.height
            let x = 0.0
            let y = 0.0
            imageView.frame = CGRect.init(x: x, y: y, width: width, height: height)
        }
    }
    
    @objc
    func saveAction(){
        print("save")
        UIImageWriteToSavedPhotosAlbum(self.imageView.image!, self, #selector(saved(_:didFinishSavingWithError:contextInfo:)),nil)
    }
    
    @objc func saved(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            // we got back an error!
            let ac = UIAlertController(title: "Save error", message: error.localizedDescription, preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        } else {
            let ac = UIAlertController(title: "Saved!", message: "The image has been saved to your photos.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))
            present(ac, animated: true)
        }
    }

}

