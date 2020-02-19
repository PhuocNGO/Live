//
//  LiveFeedAudienceViewController.swift
//  PuffyApp
//
//  Created by Apple2 on 10/14/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import PhenixSdk

class LiveFeedAudienceViewController: LiveController {

    @IBOutlet var subscriberVideoView: UIView!
    @IBOutlet weak var chatOverlayContainer: UIView!
    @IBOutlet weak var placeHolderOverlayContainer: UIView!
    @IBOutlet weak var mutedIcon: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideNavigationBar()
        toogleUIForChat()
        updateUIForAudience()
        
        // Do any additional setup after loading the view.
        phenix.initializeForView(viewLayer: subscriberVideoView.layer)
        phenix.joinRoom(roomAlias: roomAlias, notificationHandler: onPhenixNotification)
        if self.broadcastType == .chat {
            self.placeHolderOverlayContainer.backgroundColor = DefaultsData.defaultChatRoomColor
        } else {
            self.placeHolderOverlayContainer.backgroundColor = .clear
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func dismissPopupSheet(animated shouldAnimate: Bool, completion: ((Bool) -> ())?) {
        super.dismissPopupSheet()
    }
    
    override func streamStart() {
        super.streamStart()
        DispatchQueue.main.async(execute: { [weak self] in
            self?.placeHolderOverlayContainer.isHidden = true
        })
    }
    
    override func updatePreferredBackgroundColor(_ color: UIColor) {
        super.updatePreferredBackgroundColor(color)
        DispatchQueue.main.async(execute: { [weak self] in
            self?.placeHolderOverlayContainer.backgroundColor = color
            DefaultsData.defaultChatRoomColor = color
        })
    }
    
    override func showPlaceHolderContainer(_ url: URL?, message: String? = nil) {
        super.showPlaceHolderContainer(url)

        DispatchQueue.main.async(execute: { [weak self] in
            self?.trailerOverlayVC?.placeholderImageUrl = url
            self?.placeHolderOverlayContainer.isHidden = false
            if self?.broadcastType != .chat {
                self?.trailerOverlayVC?.contentView.isHidden = false
                if let startAt = self?.storyOptions?.liveSettings["startAt"] as? Int64, startAt > Date().millisecondsSince1970 {
                    self?.trailerOverlayVC?.startAt = Date.init(milliseconds: startAt)
                    self?.trailerOverlayVC?.startTimer()
                } else if let endAt = self?.storyOptions?.liveSettings["endAt"] as? Int64, 0 < endAt, endAt < Date().millisecondsSince1970 {
                    self?.trailerOverlayVC?.showcaseCaptionLabel.text = ""
                    self?.trailerOverlayVC?.descriptionLabel.text = "Streaming ended at: "
                    self?.trailerOverlayVC?.timeLabel.text = Date().getDateString(from: Date(milliseconds: endAt))
                } else if self?.members.count == 1, self?.phenix.broadcastType == .showcase {
                    self?.trailerOverlayVC?.showcaseCaptionLabel.text = ""
                    self?.trailerOverlayVC?.descriptionLabel.text = "Streaming ended."
                } else if let message = message {
                    self?.trailerOverlayVC?.showcaseCaptionLabel.text = ""
                    self?.trailerOverlayVC?.descriptionLabel.text = message
                } else {
                    self?.trailerOverlayVC?.contentView.isHidden = true
                }
            } else {
                self?.trailerOverlayVC?.contentView.isHidden = true
            }
        })
    }
    
    override func endLiveView() {
        var actions: [AlertAction] = []
        actions.append(AlertAction(title: "Cancel", handler: nil))
        let alert = AlertPopupVC(title: "Are you sure you want to leave the room?", detail: nil, action: AlertAction(title: "Leave") { [weak self] in
            self?.phenix.leaveRoom() { [weak self] in
                DispatchQueue.main.async {
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        })
        present(alert, animated: true)
    }
    
    @IBAction func closeButtonTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
}
