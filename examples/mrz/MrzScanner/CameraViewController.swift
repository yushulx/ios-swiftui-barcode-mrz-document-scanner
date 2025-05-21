import DynamsoftMRZScannerBundle

let kAllTemplateNameList: [String] = ["ReadId", "ReadPassport", "ReadPassportAndId"]
var defaultTemplateIndex: Int = 2

class CameraViewController: UIViewController {
    private var currentTemplateName = kAllTemplateNameList[defaultTemplateIndex]
    private let dce = CameraEnhancer()
    private let cameraView = CameraView()
    private let cvr = CaptureVisionRouter()
    private let model = ParsedItemModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setLicense()
        setUpCamera()
        setUpDCV()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        dce.open()
        cvr.startCapturing(currentTemplateName) { isSuccess, error in
            if !isSuccess {
                if let error = error {
                    self.showResult("Error", error.localizedDescription)
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dce.close()
        dce.clearBuffer()
        cvr.stopCapturing()
    }

    func setUpCamera() {
        cameraView.frame = view.bounds
        cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(cameraView, at: 0)
        dce.cameraView = cameraView
    }

    func setUpDCV() {
        // Set the camera enhancer as the input.
        try! cvr.setInput(dce)
        // Add CapturedResultReceiver to receive the result callback when a video frame is processed.
        cvr.addResultReceiver(self)
    }

    private func showResult(_ title: String, _ message: String?, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(
                UIAlertAction(title: "OK", style: .default, handler: { _ in completion?() }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 20)
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.heightAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.25),
            textView.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
        return textView
    }()
}

// MARK: CapturedResultReceiver
extension CameraViewController: CapturedResultReceiver {

    func onCapturedResultReceived(_ result: CapturedResult) {
        if let item = result.parsedResult?.items?.first, model.isLegalMRZ(item) {
            DispatchQueue.main.async {
                self.cvr.stopCapturing()
                self.dce.clearBuffer()
                self.dce.cameraView.getDrawingLayer(DrawingLayerId.DLR.rawValue)?.visible =
                    false
                let vc = MRZResultViewController()
                vc.mrzResultModel = self.model
                vc.delegate = self
                vc.modalPresentationStyle = .overCurrentContext  // Make it hover over the current view
                vc.view.backgroundColor = UIColor.black.withAlphaComponent(0.3)  // 70% opacity background
                vc.preferredContentSize = CGSize(
                    width: self.view.bounds.width * 0.8, height: self.view.bounds.height * 0.6)
                self.present(vc, animated: true, completion: nil)
            }
        } else {
            if let text = result.recognizedTextLinesResult?.items?.first?.text {
                DispatchQueue.main.async {
                    self.textView.text = "Failed to parse the result!\nThe text is :\n" + text
                }
            }
        }
    }
}

// MARK: LicenseVerificationListener
extension CameraViewController: LicenseVerificationListener {

    func onLicenseVerified(_ isSuccess: Bool, error: Error?) {
        if !isSuccess {
            if let error = error {
                print("\(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.displayLicenseMessage(
                        message: "License initialization failed：" + error.localizedDescription)
                }
            }
        }
    }

    func setLicense() {
        LicenseManager.initLicense(
            "DLS2eyJoYW5kc2hha2VDb2RlIjoiMjAwMDAxLTE2NDk4Mjk3OTI2MzUiLCJvcmdhbml6YXRpb25JRCI6IjIwMDAwMSIsInNlc3Npb25QYXNzd29yZCI6IndTcGR6Vm05WDJrcEQ5YUoifQ==",
            verificationDelegate: self)
    }

    func displayLicenseMessage(message: String) {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .red
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])
    }
}

extension CameraViewController: MRZResultViewControllerDelegate {

    func restartCapturing() {
        // Restart the camera capturing process after returning from the MRZResultViewController
        cvr.startCapturing(currentTemplateName) { isSuccess, error in
            if !isSuccess, let error = error {
                self.showResult("Error", error.localizedDescription)
            }
        }
    }
}
