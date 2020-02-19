//
//  LiveWaitingOverlayVC.swift
//  PuffyApp
//
//  Created by Apple2 on 11/11/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit

class LivePlaceHolderOverlayVC: UIViewController {
    
    @IBOutlet weak var contentView: UIView! {
        didSet {
            if contentView.isHidden == true {
                self.stopTimer()
            } else {
                self.startTimer()
            }
        }
    }
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var watchTrailerButton: UIButton!
    @IBOutlet weak var showcaseCaptionLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    var startAt: Date? = nil
    var timer: Timer? = nil
    
    var placeholderImageUrl: URL? {
        didSet {
            guard let url = placeholderImageUrl else { return }
            UIImage.image(from: url) { [weak self] (image) in
                self?.imageView?.image = image
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        timeLabel.adjustsFontSizeToFitWidth = true
        imageView?.isHidden = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        imageView?.isHidden = true
        stopTimer()
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(updateTimer)), userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func updateTimer() {
        guard let startAt = startAt else { return }
        timeLabel.text = startAt.timeStringSinceNow()
    }
}
