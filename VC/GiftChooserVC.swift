//
//  GiftChooseVC.swift
//  PuffyApp
//
//  Created by Apple2 on 11/16/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit

class GiftChooserVC: UIViewController {
    
    var didChooseGift: ((Int)->Void)?
    
    override func viewDidLoad() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func giftButtonPressed(_ sender: UIButton) {
        didChooseGift?(sender.tag)
    }
}
