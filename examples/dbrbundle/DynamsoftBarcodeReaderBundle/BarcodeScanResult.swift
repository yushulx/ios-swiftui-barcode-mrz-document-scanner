//
//  BarcodeScanResult.swift
//  DynamsoftBarcodeReaderBundle
//
//  Copyright © Dynamsoft Corporation.  All rights reserved.
//

import Foundation
import DynamsoftBarcodeReader

@objc(DSResultStatus)
public enum ResultStatus:Int {
    case finished
    case canceled
    case exception
}

@objcMembers
@objc(DSBarcodeScanResult)
public class BarcodeScanResult: NSObject {
    public let resultStatus:ResultStatus
    public let barcodes: [BarcodeResultItem]?
    public let errorCode: Int
    public let errorString: String?
    init(resultStatus: ResultStatus, barcodes: [BarcodeResultItem]? = nil, errorCode: Int = 0, errorString: String? = nil) {
        self.resultStatus = resultStatus
        self.barcodes = barcodes
        self.errorCode = errorCode
        self.errorString = errorString
    }
}
