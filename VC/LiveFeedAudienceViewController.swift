//
//  LiveFeedAudienceViewController.swift
//  PuffyApp
//
//  Created by Apple2 on 10/14/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import PhenixSdk

class LiveFeedAudienceViewController: PuffyVC {
    
    @IBOutlet weak var subscriberVideoView: UIView!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var chatButton: UIButton!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var viewerIcon: UIImageView!
    @IBOutlet weak var chatOverlayContainer: UIView!
    
    var timer = Timer()
    var seconds = 0
    
    private var phenix: PhenixRoomHelper = PhenixRoomHelper()
    var overlayController: LiveOverlayVC!
    
    private var isShowComment: Bool = false {
        didSet {
            chatButton.setBackgroundImage(isShowComment ? #imageLiteral(resourceName: "chatDisabledIcon") : #imageLiteral(resourceName: "chatEnableIcon"), for: .normal)
            chatOverlayContainer.isHidden = !isShowComment
        }
    }
    
    private var isShowInfo: Bool = false {
        didSet {
            infoButton.setBackgroundImage(isShowInfo ? #imageLiteral(resourceName: "liveInfoIconDisable") : #imageLiteral(resourceName: "liveInfoIcon"), for: .normal)
        }
    }

    public var roomId: String {
        get { return self.phenix.roomId }
        set { self.phenix.roomId = newValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideNavigationBar()
        
        let viewerGesture = UITapGestureRecognizer(target: self, action: #selector(viewerTapped))
        viewerIcon.addGestureRecognizer(viewerGesture)
        
        // Do any additional setup after loading the view.
        phenix.initializeForView(viewLayer: subscriberVideoView.layer)
        runTimer()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func dismissPopupSheet(animated shouldAnimate: Bool, completion: ((Bool) -> ())?) {
        super.dismissPopupSheet()
        if popupSheetVC is LiveInfoVC {
            isShowInfo = false
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "overlay" {
            overlayController = segue.destination as? LiveOverlayVC
        }
    }
    
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(updateTimer)), userInfo: nil, repeats: true)
    }
    
    @objc func updateTimer() {
        seconds += 1
        durationLabel.text = String(time: TimeInterval(seconds)).trimmingCharacters(in: .whitespaces)
    }
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func infoButtonTapped(_ sender: Any) {
        isShowComment = false
        if isShowInfo {
            
        } else {
            if let controller = UIStoryboard(name: "LiveFeedVC", bundle: nil).instantiateViewController(withIdentifier: LiveInfoVC.nameOfClass) as? LiveInfoVC {
                presentSheet(with: controller, height: self.view.frame.height * 1/3)
                isShowInfo = true
            }
        }
    }
    
    @IBAction func chatButtonTapped(_ sender: Any) {
        isShowInfo = false
        isShowComment = !isShowComment
        if isShowComment {
            isShowInfo = false
        }
    }
    
    @objc private func viewerTapped(recognizer: UITapGestureRecognizer) {
        isShowComment = false
        let vc = UIStoryboard(name: UIStoryboard.Name.listUsers, bundle: nil).instantiateViewController(withIdentifier: ListShowcaseLikersTableVC.nameOfClass) as! ListShowcaseLikersTableVC
        vc.preferredMainBackground = UIColor.Puffy.Theme.Grayscale.tg1.withAlphaComponent(0.45)
        vc.showcaseId = ""
        vc.title = "76 Viewers"
        presentSheet(with: vc, height: 200)
    }
}
