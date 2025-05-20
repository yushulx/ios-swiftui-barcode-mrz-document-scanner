import Foundation

public enum ScanMode {
    case mrz
    case vin
}

@objc(DSDocumentType)
public enum DocumentType: Int {
    case all
    case id
    case passport
}

@objcMembers
@objc(DSScannerConfig)
public class ScannerConfig: NSObject {
    public var license: String!
    @available(*, deprecated, message: "Use `templateFile` instead")
    public var templateFilePath: String?
    public var templateFile: String?
    public var isTorchButtonVisible: Bool = true
    public var isBeepEnabled: Bool = true
    public var isCloseButtonVisible: Bool = true
    public var documentType: DocumentType = .all
    public var isGuideFrameVisible: Bool = true
    public var isCameraToggleButtonVisible: Bool = false
    public var mode: ScanMode = ScanMode.mrz
}
