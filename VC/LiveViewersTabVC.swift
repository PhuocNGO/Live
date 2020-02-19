//
//  LiveViewersTab.swift
//  PuffyApp
//
//  Created by Apple2 on 12/7/18.
//  Copyright © 2018 Puffy. All rights reserved.
//
import UIKit
import XLPagerTabStrip

class LiveViewersTabVC: TabVC {
    
    var sections: [String: [ListUser]] = [:]
    var didSelectUser: ((ListUser)->Void)?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didTabChange(oldCell: ButtonBarViewCell?, newCell: ButtonBarViewCell?) {
        let unfocusedColor: UIColor = UIColor.Puffy.Theme.Grayscale.tg4
        let focusedColor: UIColor = UIColor.Puffy.Green.booger
        
        oldCell?.isHighlighted = false
        newCell?.isHighlighted = true
        oldCell?.label.textColor = unfocusedColor
        newCell?.label.textColor = focusedColor
    }
    
    /// Sets the custom look of the tab bar.
    override func customizeTabUI() {
        super.customizeTabUI()
        
        settings.style.buttonBarBackgroundColor = UIColor.Puffy.Theme.Grayscale.mainBackground
        settings.style.selectedBarBackgroundColor = UIColor.Puffy.Green.booger
    }
    
    override func viewControllers(for pagerTabStripController: PagerTabStripViewController) -> [UIViewController] {
        return sections.sorted(by: { $0.0 > $1.0 }).compactMap { (dictionary) -> ListLiveMembersTableVC? in
            let vc = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: ListLiveMembersTableVC.nameOfClass) as! ListLiveMembersTableVC
            vc.sectionName = dictionary.key
            vc.puffers = dictionary.value
            vc.didSelectUser = { [weak self] (user) in
                self?.didSelectUser?(user)
            }
            return vc
        }
    }
}
