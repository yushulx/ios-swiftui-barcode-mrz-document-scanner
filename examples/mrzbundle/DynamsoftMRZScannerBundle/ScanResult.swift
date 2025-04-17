import Foundation

@objc(DSResultStatus)
public enum ResultStatus: Int {
    case finished
    case canceled
    case exception
}

@objcMembers
@objc(DSScanResultBase)
public class ScanResultBase: NSObject {
    public let resultStatus: ResultStatus
    public let errorCode: Int
    public let errorString: String?

    init(resultStatus: ResultStatus, errorCode: Int = 0, errorString: String? = nil) {
        self.resultStatus = resultStatus
        self.errorCode = errorCode
        self.errorString = errorString
    }
}

@objcMembers
@objc(DSMRZData)
public class MRZData: NSObject {
    public let firstName: String
    public let lastName: String
    public let sex: String
    public let issuingState: String
    public let nationality: String
    public let dateOfBirth: String
    public let dateOfExpire: String
    public let documentType: String
    public let documentNumber: String
    public let age: Int
    public let mrzText: String
    init(
        firstName: String, lastName: String, sex: String, issuingState: String, nationality: String,
        dateOfBirth: String, dateOfExpire: String, documentType: String, documentNumber: String,
        age: Int, mrzText: String
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.sex = sex
        self.issuingState = issuingState
        self.nationality = nationality
        self.dateOfBirth = dateOfBirth
        self.dateOfExpire = dateOfExpire
        self.documentType = documentType
        self.documentNumber = documentNumber
        self.age = age
        self.mrzText = mrzText
    }
}

public class MRZScanResult: ScanResultBase {
    public let data: MRZData?

    init(
        resultStatus: ResultStatus, mrzdata: MRZData? = nil, errorCode: Int = 0,
        errorString: String? = nil
    ) {
        self.data = mrzdata
        super.init(resultStatus: resultStatus, errorCode: errorCode, errorString: errorString)
    }
}

@objcMembers
@objc(DSVINData)
public class VINData: NSObject {
    public let vinString: String
    public let wmi: String
    public let region: String
    public let vds: String
    public let checkDigit: String
    public let modelYear: String
    public let plantCode: String
    public let serialNumber: String

    init(
        vinString: String, wmi: String, region: String, vds: String, checkDigit: String,
        modelYear: String, plantCode: String, serialNumber: String
    ) {
        self.vinString = vinString
        self.wmi = wmi
        self.region = region
        self.vds = vds
        self.checkDigit = checkDigit
        self.modelYear = modelYear
        self.plantCode = plantCode
        self.serialNumber = serialNumber
    }
}

public class VINScanResult: ScanResultBase {
    public let data: VINData?

    init(
        resultStatus: ResultStatus, vindata: VINData? = nil, errorCode: Int = 0,
        errorString: String? = nil
    ) {
        self.data = vindata
        super.init(resultStatus: resultStatus, errorCode: errorCode, errorString: errorString)
    }
}
