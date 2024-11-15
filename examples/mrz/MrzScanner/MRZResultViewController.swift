import Foundation
import UIKit

protocol MRZResultViewControllerDelegate: AnyObject {
    func restartCapturing()
}

class MRZResultViewController: UIViewController {

    var mrzResultModel: ParsedItemModel!
    private var resultListArray: [[String : String]] = []
    weak var delegate: MRZResultViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "MRZ Result"
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        let contentView = UIView()
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        
        // Define the content size and position
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            contentView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8), // 80% of the screen width
            contentView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6) // 60% of the screen height
        ])

        analyzeData()
        setupUI(in: contentView)
    }

    func analyzeData() {
        resultListArray = [["Title": "Document Type", "Content":mrzResultModel.documentType],
                           ["Title": "Document Number:", "Content":mrzResultModel.documentNumber],
                           ["Title": "Name:", "Content":mrzResultModel.name],
                           ["Title": "Gender:", "Content":mrzResultModel.gender],
                           ["Title": "Age:", "Content":mrzResultModel.age != -1 ? String(format: "%ld", mrzResultModel.age) : "Unknown"],
                           ["Title": "Issuing State:", "Content":mrzResultModel.issuingState],
                           ["Title": "Nationality:", "Content":mrzResultModel.nationality],
                           ["Title": "Date of Birth(YYYY-MM-DD):", "Content":mrzResultModel.dateOfBirth],
                           ["Title": "Date of Expiry(YYYY-MM-DD):", "Content":mrzResultModel.dateOfExpiry]
        ]
    }
    
    func setupUI(in contentView: UIView) {
        let safeArea = contentView.safeAreaLayoutGuide
        
        // Create and configure the table view inside the content view (popup dialog)
        let tableView = UITableView()
        tableView.flashScrollIndicators()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
        
        // Add a dismiss button (Back) inside the content view (popup dialog)
        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Back", for: .normal)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissViewController), for: .touchUpInside)
        contentView.addSubview(dismissButton)
        
        // Set the button's position at the top-right corner of the content view
        NSLayoutConstraint.activate([
            dismissButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20), // 20 points from the top
            dismissButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20) // 20 points from the right
        ])
    }
    
    @objc func dismissViewController() {
        delegate?.restartCapturing()
        self.dismiss(animated: true, completion: nil)
    }
}

extension MRZResultViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultListArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let dataInfo = self.resultListArray[indexPath.row]
        let title = dataInfo["Title"] ?? ""
        let subTitle = dataInfo["Content"] ?? ""
    
        let identifier = "DCPResultCell"
        var cell = tableView.dequeueReusableCell(withIdentifier: identifier)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        }
        cell?.selectionStyle = .none
        cell?.textLabel?.text = title
        cell?.textLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
        cell?.detailTextLabel?.text = subTitle
        cell?.detailTextLabel?.font = UIFont.systemFont(ofSize: 14.0)
        cell?.detailTextLabel?.textColor = .lightGray
        cell?.detailTextLabel?.numberOfLines = 0
        return cell!
    }
}
