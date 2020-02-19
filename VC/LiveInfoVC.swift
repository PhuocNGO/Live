//
//  LiveInfoVC.swift
//  PuffyApp
//
//  Created by Apple2 on 11/1/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit

class LiveInfoVC : PuffyVC {
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(LiveInfoTVC.nib(), forCellReuseIdentifier: LiveInfoTVC.nameOfClass)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = .clear
    }
}

extension LiveInfoVC: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LiveInfoTVC.nameOfClass, for: indexPath) as! LiveInfoTVC
        cell.captionLabel.text = String.random(length: 500)
        return cell
    }
}
