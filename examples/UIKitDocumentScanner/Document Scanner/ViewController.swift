//
//  ViewController.swift
//  Document Scanner
//
//  Created by xulihang on 2022/11/27.
//

import UIKit

class ViewController: UIViewController {
    var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.button = UIButton(frame: .zero)
        self.button.setTitle("Scan Document", for: .normal)
        self.button.setTitleColor(.systemBlue, for: .normal)
        self.button.setTitleColor(.lightGray, for: .highlighted)

        self.button.addTarget(self,
                         action: #selector(buttonAction),
                         for: .touchUpInside)
        self.navigationItem.title = "Home"
        
        self.view.backgroundColor = UIColor.white
        self.view.addSubview(self.button)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let button = self.button {
            let width: CGFloat = 300
            let height: CGFloat = 50
            let x = view.frame.width/2 - width/2
            let y = view.frame.height - 100
            button.frame = CGRect.init(x: x, y: y, width: width, height: height)
        }
    }
    
    @objc
    func buttonAction() {
        print("button pressed")
        //let nav = UINavigationController(rootViewController: CameraController())
        //nav.modalPresentationStyle = .fullScreen
        //self.present(nav, animated: true, completion: nil)
        self.navigationController?.pushViewController(CameraController(), animated: true)
    }
}

