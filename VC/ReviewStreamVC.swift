//
//  ReviewStreamVC.swift
//  PuffyApp
//
//  Created by Apple2 on 10/26/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit

class ReviewStreamVC : PuffyVC {
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rightButton = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: self,
            action: #selector(handleEndStreamingTap)
        )
        rightButton.tintColor = UIColor.Puffy.Green.booger
        self.navigationItem.rightBarButtonItem = rightButton
        self.title = "My Stream"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    @objc private func handleEndStreamingTap() {
        self.dismiss(animated: true, completion: nil)
    }
}
