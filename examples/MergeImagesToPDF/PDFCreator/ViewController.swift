//
//  ViewController.swift
//  PDFCreator
//
//  Created by xulihang on 2024/6/14.
//

import UIKit
import PhotosUI
import PDFKit
import DynamsoftCaptureVisionBundle

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, PHPickerViewControllerDelegate {
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var selectImagesUIButton: UIButton!
    @IBOutlet weak var colorModeUIPickerView: UIPickerView!
    @IBOutlet weak var enableAutoCroppingUISwitch: UISwitch!
    let cvr:CaptureVisionRouter = CaptureVisionRouter()
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        DispatchQueue.main.async {
            var images:[UIImage] = []
            var processed = 0
            let size = results.count
            for item in results {
                if (item.itemProvider.canLoadObject(ofClass: UIImage.self)) {
                    item.itemProvider.loadObject(ofClass: UIImage.self) { image , error  in
                        if let error {
                            NSLog("Failed to load the picked image: %@", error.localizedDescription)
                        }
                        if let selectedImage = image as? UIImage{
                            images.append(selectedImage)
                            processed = processed + 1
                            if processed == size {
                                self.mergeImagesIntoPDF(images: images)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func mergeImagesIntoPDF(images:[UIImage]) {
        var enableAutoCropping = false
        var selectedColorModeIndex = 0
        DispatchQueue.main.sync {
            statusLabel.text = "Processing..."
            enableAutoCropping = enableAutoCroppingUISwitch.isOn
            selectedColorModeIndex = colorModeUIPickerView.selectedRow(inComponent: 0)
        }

        let templateName = enableAutoCropping
            ? PresetTemplate.detectAndNormalizeDocument.rawValue
            : PresetTemplate.normalizeDocument.rawValue

        guard let settings = try? cvr.getSimplifiedSettings(templateName) else {
            statusLabel.text = ""
            return
        }

        switch selectedColorModeIndex {
        case 0:
            settings.documentSettings?.colourMode = ImageColourMode.binary
        case 1:
            settings.documentSettings?.colourMode = ImageColourMode.grayscale
        default:
            settings.documentSettings?.colourMode = ImageColourMode.colour
        }

        if !enableAutoCropping {
            // Normalize the whole image when document detection is off.
            let fullPage = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0), CGPoint(x: 100, y: 100), CGPoint(x: 0, y: 100)]
            settings.roi = Quadrilateral(pointArray: fullPage.map { NSValue(cgPoint: $0) })
            settings.roiMeasuredInPercentage = true
        }
        try? cvr.updateSettings(templateName, settings: settings)

        let pdfDocument = PDFDocument()
        for image in images {
            let capturedResult = cvr.captureFromImage(image, templateName: templateName)
            // 3.x exposes the normalized page through processedDocumentResult. ImageIO.saveToFile
            // overwrites the target file, so PDFKit is used to append one page per image.
            let deskewedItems = capturedResult.processedDocumentResult?.deskewedImageResultItems ?? []
            for item in deskewedItems {
                if let imageData = item.imageData,
                   let pageImage = try? imageData.toUIImage(),
                   let page = PDFPage(image: pageImage) {
                    pdfDocument.insert(page, at: pdfDocument.pageCount)
                }
            }
        }
        let url = FileManager.default.temporaryDirectory
                                                        .appendingPathComponent(UUID().uuidString)
                                                        .appendingPathExtension("pdf")
        pdfDocument.write(to: url)
        DispatchQueue.main.async {
            self.statusLabel.text = ""
            let objectsToShare = [url]
            let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)

            self.present(activityVC, animated: true, completion: nil)
        }
        
    }
    
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 3
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int,
                        forComponent component: Int) -> String? {
        if row == 0 {
            return "Black & White"
        }else if row == 1 {
            return "Grayscale"
        }else{
            return "Color"
        }
                
    }
    
   
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        colorModeUIPickerView.dataSource = self
        colorModeUIPickerView.delegate = self
    }

    @IBAction func selectImagesUIButton_clicked(_ sender: Any) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        //0 - unlimited 1 - default
        configuration.selectionLimit = 0
        configuration.filter = .images
        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        present(pickerViewController, animated: true)
    }
}

