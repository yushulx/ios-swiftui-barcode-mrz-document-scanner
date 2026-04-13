//
//  BarcodeDetector.swift
//  BarcodeBenchmark
//
//  Barcode detector implementations for Dynamsoft, MLKit, and Apple Vision
//

import UIKit
import AVFoundation
import Vision
import CoreImage

// MARK: - Dynamsoft Barcode Detector

#if canImport(DynamsoftCaptureVisionBundle)
import DynamsoftCaptureVisionBundle
import DynamsoftBarcodeReaderBundle

class DynamsoftBarcodeDetector: NSObject, BarcodeDetector, LicenseVerificationListener {

    private let cvr: CaptureVisionRouter

    override init() {
        cvr = CaptureVisionRouter()
        super.init()
        // Use a trial license key. Request a permanent key at https://www.dynamsoft.com/customer/license/trialLicense/?product=dcv&package=cross-platform
        LicenseManager.initLicense("DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ==", verificationDelegate: self)
    }

    func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
        if !isSuccess {
            print("Dynamsoft license error: \(error?.localizedDescription ?? "Unknown error")")
        }
    }

    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo] {
        let result = cvr.captureFromImage(image, templateName: "ReadBarcodes_Default")
        return parseResult(result, imageSize: image.size)
    }

    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
            throw DetectionError.invalidImage
        }
        return try await detectBarcodes(in: UIImage(cgImage: cgImage))
    }

    private func parseResult(_ result: CapturedResult, imageSize: CGSize) -> [BarcodeInfo] {
        guard let items = result.decodedBarcodesResult?.items else { return [] }
        return items.map { item in
            // DSQuadrilateral exposes a pre-computed boundingRect — no need to iterate points.
            let bounds: CGRect? = {
                guard imageSize.width > 0, imageSize.height > 0 else { return nil }
                let br = item.location.boundingRect
                return CGRect(
                    x: br.minX / imageSize.width,
                    y: br.minY / imageSize.height,
                    width: br.width / imageSize.width,
                    height: br.height / imageSize.height)
            }()
            return BarcodeInfo(format: item.formatString ?? "", text: item.text ?? "", decodeTimeMs: 0, normalizedBounds: bounds)
        }
    }
}

#else

class DynamsoftBarcodeDetector: BarcodeDetector {
    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo] {
        throw DetectionError.notInitialized
    }
    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo] {
        throw DetectionError.notInitialized
    }
}

#endif

// MARK: - MLKit Barcode Detector

#if canImport(MLKitBarcodeScanning)
import MLKitBarcodeScanning
import MLKitVision

class MLKitBarcodeDetector: BarcodeDetector {

    private let scanner: MLKitBarcodeScanning.BarcodeScanner

    init() {
        let options = BarcodeScannerOptions(formats: .all)
        scanner = MLKitBarcodeScanning.BarcodeScanner.barcodeScanner(options: options)
    }

    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo] {
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        let imgW = image.size.width
        let imgH = image.size.height
        return try await withCheckedThrowingContinuation { continuation in
            scanner.process(visionImage) { [weak self] barcodes, error in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }
                if let error = error {
                    continuation.resume(throwing: DetectionError.detectionFailed(error.localizedDescription))
                    return
                }
                let results = (barcodes ?? []).map { barcode -> BarcodeInfo in
                    var bounds: CGRect?
                    if imgW > 0 && imgH > 0 {
                        let f = barcode.frame
                        bounds = CGRect(x: f.minX / imgW, y: f.minY / imgH,
                                        width: f.width / imgW, height: f.height / imgH)
                    }
                    return BarcodeInfo(
                        format: self.mapFormat(barcode.format),
                        text: barcode.rawValue ?? barcode.displayValue ?? "",
                        decodeTimeMs: 0,
                        normalizedBounds: bounds
                    )
                }
                continuation.resume(returning: results)
            }
        }
    }

    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo] {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
            throw DetectionError.invalidImage
        }
        return try await detectBarcodes(in: UIImage(cgImage: cgImage))
    }

    private func mapFormat(_ format: MLKitBarcodeScanning.BarcodeFormat) -> String {
        if format.contains(.qrCode)    { return "QR_CODE" }
        if format.contains(.code128)   { return "CODE_128" }
        if format.contains(.code39)    { return "CODE_39" }
        if format.contains(.code93)    { return "CODE_93" }
        if format.contains(.codaBar)   { return "CODABAR" }
        if format.contains(.dataMatrix){ return "DATA_MATRIX" }
        if format.contains(.EAN13)     { return "EAN_13" }
        if format.contains(.EAN8)      { return "EAN_8" }
        if format.contains(.ITF)       { return "ITF" }
        if format.contains(.UPCA)      { return "UPC_A" }
        if format.contains(.UPCE)      { return "UPC_E" }
        if format.contains(.PDF417)    { return "PDF417" }
        if format.contains(.aztec)     { return "AZTEC" }
        return "UNKNOWN"
    }
}

#else

class MLKitBarcodeDetector: BarcodeDetector {
    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo] {
        throw DetectionError.notInitialized
    }
    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo] {
        throw DetectionError.notInitialized
    }
}

#endif

// MARK: - Apple Vision Barcode Detector
class VisionBarcodeDetector: BarcodeDetector {
    
    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo] {
        guard let cgImage = image.cgImage else {
            throw DetectionError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: DetectionError.detectionFailed(error.localizedDescription))
                    return
                }
                
                guard let results = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let barcodes = results.map { observation -> BarcodeInfo in
                    let format = self.mapSymbology(observation.symbology)
                    let text = observation.payloadStringValue ?? ""
                    // boundingBox origin is bottom-left; flip Y for top-left screen coords
                    let bb = observation.boundingBox
                    let bounds = CGRect(x: bb.minX, y: 1.0 - bb.maxY, width: bb.width, height: bb.height)
                    return BarcodeInfo(format: format, text: text, decodeTimeMs: 0, normalizedBounds: bounds)
                }
                
                continuation.resume(returning: barcodes)
            }
            
            // Request all supported barcode types
            request.symbologies = [
                .qr,
                .code128,
                .code39,
                .code93,
                .ean8,
                .ean13,
                .upce,
                .pdf417,
                .aztec,
                .dataMatrix,
                .codabar,
                .itf14
            ]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: DetectionError.detectionFailed(error.localizedDescription))
            }
        }
    }
    
    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: DetectionError.detectionFailed(error.localizedDescription))
                    return
                }
                
                guard let results = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let barcodes = results.map { observation -> BarcodeInfo in
                    let format = self.mapSymbology(observation.symbology)
                    let text = observation.payloadStringValue ?? ""
                    // boundingBox origin is bottom-left; flip Y for top-left screen coords
                    let bb = observation.boundingBox
                    let bounds = CGRect(x: bb.minX, y: 1.0 - bb.maxY, width: bb.width, height: bb.height)
                    return BarcodeInfo(format: format, text: text, decodeTimeMs: 0, normalizedBounds: bounds)
                }
                
                continuation.resume(returning: barcodes)
            }
            
            request.symbologies = [
                .qr,
                .code128,
                .code39,
                .code93,
                .ean8,
                .ean13,
                .upce,
                .pdf417,
                .aztec,
                .dataMatrix,
                .codabar,
                .itf14
            ]
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: DetectionError.detectionFailed(error.localizedDescription))
            }
        }
    }
    
    private func mapSymbology(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr:
            return "QR_CODE"
        case .code128:
            return "CODE_128"
        case .code39:
            return "CODE_39"
        case .code93:
            return "CODE_93"
        case .ean8:
            return "EAN_8"
        case .ean13:
            return "EAN_13"
        case .upce:
            return "UPC_E"
        case .pdf417:
            return "PDF417"
        case .aztec:
            return "AZTEC"
        case .dataMatrix:
            return "DATA_MATRIX"
        case .codabar:
            return "CODABAR"
        case .itf14:
            return "ITF"
        default:
            return "UNKNOWN"
        }
    }
}

// MARK: - ZXing-CPP Barcode Detector

#if canImport(ZXingCpp)
import ZXingCpp

class ZXingCppBarcodeDetector: BarcodeDetector {

    private let reader: ZXIBarcodeReader

    init() {
        reader = ZXIBarcodeReader()
    }

    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo] {
        guard let cgImage = image.cgImage else {
            throw DetectionError.invalidImage
        }
        let results = try reader.read(cgImage)
        let imgW = Int(image.size.width)
        let imgH = Int(image.size.height)
        return results.map { r in
            var bounds: CGRect?
            if imgW > 0 && imgH > 0 {
                let pos = r.position
                let xs = [pos.topLeft.x, pos.topRight.x, pos.bottomRight.x, pos.bottomLeft.x]
                let ys = [pos.topLeft.y, pos.topRight.y, pos.bottomRight.y, pos.bottomLeft.y]
                if let minX = xs.min(), let maxX = xs.max(),
                   let minY = ys.min(), let maxY = ys.max() {
                    bounds = CGRect(
                        x: CGFloat(minX) / CGFloat(imgW),
                        y: CGFloat(minY) / CGFloat(imgH),
                        width: CGFloat(maxX - minX) / CGFloat(imgW),
                        height: CGFloat(maxY - minY) / CGFloat(imgH)
                    )
                }
            }
            return BarcodeInfo(
                format: mapFormat(r.format),
                text: r.text,
                decodeTimeMs: 0,
                normalizedBounds: bounds
            )
        }
    }

    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo] {
        let results = try reader.read(pixelBuffer)
        let bufW = CVPixelBufferGetWidth(pixelBuffer)
        let bufH = CVPixelBufferGetHeight(pixelBuffer)
        return results.map { r in
            var bounds: CGRect?
            if bufW > 0 && bufH > 0 {
                let pos = r.position
                let xs = [pos.topLeft.x, pos.topRight.x, pos.bottomRight.x, pos.bottomLeft.x]
                let ys = [pos.topLeft.y, pos.topRight.y, pos.bottomRight.y, pos.bottomLeft.y]
                if let minX = xs.min(), let maxX = xs.max(),
                   let minY = ys.min(), let maxY = ys.max() {
                    bounds = CGRect(
                        x: CGFloat(minX) / CGFloat(bufW),
                        y: CGFloat(minY) / CGFloat(bufH),
                        width: CGFloat(maxX - minX) / CGFloat(bufW),
                        height: CGFloat(maxY - minY) / CGFloat(bufH)
                    )
                }
            }
            return BarcodeInfo(format: mapFormat(r.format), text: r.text, decodeTimeMs: 0, normalizedBounds: bounds)
        }
    }

    // ZXIFormat is a plain C NS_ENUM; Swift does not camelCase these names so use rawValue.
    // Values (sequential from 0): NONE=0 AZTEC=1 CODABAR=2 CODE_39=3 CODE_93=4 CODE_128=5
    // DATA_BAR=6 DATA_BAR_EXPANDED=7 DATA_BAR_LIMITED=8 DATA_MATRIX=9 DX_FILM_EDGE=10
    // EAN_8=11 EAN_13=12 ITF=13 MAXICODE=14 PDF_417=15 QR_CODE=16
    // MICRO_QR_CODE=17 RMQR_CODE=18 UPC_A=19 UPC_E=20
    private func mapFormat(_ format: ZXIFormat) -> String {
        switch format.rawValue {
        case 1:  return "AZTEC"
        case 2:  return "CODABAR"
        case 3:  return "CODE_39"
        case 4:  return "CODE_93"
        case 5:  return "CODE_128"
        case 6:  return "DATA_BAR"
        case 7:  return "DATA_BAR_EXPANDED"
        case 8:  return "DATA_BAR_LIMITED"
        case 9:  return "DATA_MATRIX"
        case 11: return "EAN_8"
        case 12: return "EAN_13"
        case 13: return "ITF"
        case 15: return "PDF417"
        case 16: return "QR_CODE"
        case 17: return "MICRO_QR"
        case 18: return "RMQR"
        case 19: return "UPC_A"
        case 20: return "UPC_E"
        default: return "UNKNOWN"
        }
    }
}

#else

class ZXingCppBarcodeDetector: BarcodeDetector {
    func detectBarcodes(in image: UIImage) async throws -> [BarcodeInfo] {
        throw DetectionError.notInitialized
    }
    func detectBarcodes(in pixelBuffer: CVPixelBuffer) async throws -> [BarcodeInfo] {
        throw DetectionError.notInitialized
    }
}

#endif

// MARK: - Video Frame Extractor
class VideoFrameExtractor {
    
    static func extractFrames(from videoURL: URL, interval: Double) async throws -> [UIImage] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero
        
        var frames: [UIImage] = []
        var currentTime: Double = 0
        
        while currentTime < durationSeconds {
            let cmTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                frames.append(image)
            } catch {
                print("Failed to extract frame at \(currentTime)s: \(error)")
            }
            
            currentTime += interval
        }
        
        return frames
    }
}
