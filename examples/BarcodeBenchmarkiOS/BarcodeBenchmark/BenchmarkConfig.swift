//
//  BenchmarkConfig.swift
//  BarcodeBenchmark
//
//  Global configuration for benchmark settings
//

import Foundation

class BenchmarkConfig {
    
    /// Toggle to show/hide benchmark time in UI
    static var showBenchmarkTime: Bool = false
    
    /// Toggle to use custom Dynamsoft template or default built-in template
    static var useCustomTemplate: Bool = false
    
    /// Web server port
    static let serverPort: UInt16 = 8080
    
    /// Frame extraction interval for video processing (in seconds)
    static let frameInterval: Double = 0.5
    
    /// Dynamsoft Capture Vision Router template JSON
    static let dynamsoftTemplateJSON: String = """
    {
        "GlobalParameter": {
            "IntraOpNumThreads": 2
        },
        "CaptureVisionTemplates": [
            {
                "ImageROIProcessingNameArray": ["ROI_Default"],
                "Name": "ReadBarcodes_Default",
                "MaxParallelTasks": 0,
                "Timeout": 100
            }
        ],
        "TargetROIDefOptions": [
            {
                "Name": "ROI_Default",
                "TaskSettingNameArray": ["Task_Default"]
            }
        ],
        "BarcodeReaderTaskSettingOptions": [
            {
                "Name": "Task_Default",
                "BarcodeFormatIds": ["BF_DEFAULT"],
                "ExpectedBarcodesCount": 0,
                "MaxThreadsInOneTask": 1,
                "SectionArray": [
                    {
                        "ImageParameterName": "ip",
                        "Section": "ST_BARCODE_LOCALIZATION",
                        "StageArray": [
                            {
                                "Stage": "SST_LOCALIZE_CANDIDATE_BARCODES",
                                "LocalizationModes": [
                                    {
                                        "Mode": "LM_SCAN_DIRECTLY",
                                        "ModelNameArray": null
                                    }
                                ]
                            }
                        ]
                    },
                    {
                        "ImageParameterName": "ip",
                        "Section": "ST_BARCODE_DECODING",
                        "StageArray": [
                            {
                                "Stage": "SST_DECODE_BARCODES",
                                "DeblurModes": [
                                    {
                                        "Mode": "DM_DIRECT_BINARIZATION"
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ],
        "ImageParameterOptions": [
            {
                "ApplicableStages": [
                    {
                        "ImageScaleSetting": {
                            "EdgeLengthThreshold": 100000,
                            "ScaleType": "ST_SCALE_DOWN"
                        },
                        "Stage": "SST_SCALE_IMAGE"
                    },
                    {
                        "GrayscaleTransformationModes": [
                            {
                                "Mode": "GTM_ORIGINAL"
                            }
                        ],
                        "Stage": "SST_TRANSFORM_GRAYSCALE"
                    }
                ],
                "Name": "ip"
            }
        ]
    }
    """
}

// MARK: - Barcode Format Enum
enum BarcodeFormat: String, CaseIterable {
    case code128 = "CODE_128"
    case code39 = "CODE_39"
    case code93 = "CODE_93"
    case codabar = "CODABAR"
    case dataMatrix = "DATA_MATRIX"
    case ean13 = "EAN_13"
    case ean8 = "EAN_8"
    case itf = "ITF"
    case qrCode = "QR_CODE"
    case upcA = "UPC_A"
    case upcE = "UPC_E"
    case pdf417 = "PDF417"
    case aztec = "AZTEC"
    case unknown = "UNKNOWN"
}
