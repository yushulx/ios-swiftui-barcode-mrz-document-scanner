import Foundation
import UIKit

class MRZResultViewController: UIViewController {

    var mrzResultModel: ParsedItemModel!
    
    private var resultListArray: [[String : String]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "MRZ Result"
        view.backgroundColor = .white
        analyzeData()
        setupUI()
    }

    func analyzeData() -> Void {
        resultListArray = [["Title": "Document Type", "Content":mrzResultModel.documentType],
                           ["Title": "Document Number:", "Content":mrzResultModel.documentNumber],
                           ["Title": "Issuing State:", "Content":mrzResultModel.issuingState],
                           ["Title": "Nationality:", "Content":mrzResultModel.nationality],
                           ["Title": "Date of Birth(YYYY-MM-DD):", "Content":mrzResultModel.dateOfBirth],
                           ["Title": "Date of Expiry(YYYY-MM-DD):", "Content":mrzResultModel.dateOfExpiry],
                           
        ]
    }
    
    func setupUI() -> Void {
        let safeArea = view.safeAreaLayoutGuide
        
        let tableView = UITableView()
        tableView.flashScrollIndicators()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        ])
        
        let headerView = UIView()
        let label = UILabel()
        label.text = String(format: "%@\n%@, Age: %@", mrzResultModel.name, mrzResultModel.gender, mrzResultModel.age != -1 ? String(format: "%ld", mrzResultModel.age) : "Unknown")
        label.font = UIFont.boldSystemFont(ofSize: 20.0)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(greaterThanOrEqualTo: headerView.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -10)
            ])
        
        headerView.frame = CGRect(x: 0, y: 0, width: tableView.frame.width, height: 100)
        tableView.tableHeaderView = headerView
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
