//
//  LiveFeedViewController.swift
//  PuffyApp
//
//  Created by Apple2 on 10/9/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import PhenixSdk
import SwiftSpinner

class LiveFeedViewController: LiveController {
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var liveRenderView: UIView! {
        didSet{
            liveRenderView.isHidden = true
        }
    }
    
    @IBOutlet weak var pulseLabel: UILabel!
    @IBOutlet weak var chatOverlayView: UIView!
    private weak var createLiveInfoView: UIView?
    
    fileprivate var countDown = 30
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if broadcastType == .chat {
            self.storyOptions = StoryOptions()
            self.storyOptions?.id = DefaultsData.roomAlias ?? ""
            phenix.joinRoom(roomAlias: self.storyOptions?.id, notificationHandler: onPhenixNotification)
            phenix.initializeForView(viewLayer: liveRenderView.layer)
        } else {
            SwiftSpinner.show("Connecting")
            // Do any additional setup after loading the view.
            self.storyOptions?.liveSettings["isStreaming"] = true
            if let storyOptions = self.storyOptions, let data = storyOptions.image?.pngData() ?? ProfileManager.sharedInstance.getProfileImage()?.pngData() {
                guard storyOptions.id.isEmpty else {
                    self.initBroadcast()
                    return
                }
                self.isHost = true
                pulseLabel.isHidden = false
                APIClient.postShowcase(data: data, options: storyOptions) { [weak self] (result) in
                    switch result {
                    case .success (let data):
                        self?.storyOptions?.id = data.showcaseId
                        self?.initBroadcast()
                    case .failure(let error):
                        DispatchQueue.main.async(execute: {
                            SwiftSpinner.show(error.localizedDescription).addTapHandler({  [weak self] in
                                self?.navigationController?.popViewController(animated: false)
                                SwiftSpinner.hide()
                            })
                        })
                    }
                }
            } else {
                if self.storyOptions == nil {
                    self.storyOptions = StoryOptions()
                    self.storyOptions?.showcaseType = .live
                    self.storyOptions?.id = DefaultsData.roomAlias ?? ""
                }
                guard storyOptions?.id != nil else {
                    SwiftSpinner.show( "Invalid ID" )
                    return
                }
                self.initBroadcast()
            }
        }
        setUpUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hideNavigationBar()
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func onPhenixNotification( notification: PhenixRoomHelper.PhenixNotification ) {
        super.onPhenixNotification(notification: notification)
    }
    
    override func updatePreferredBackgroundColor(_ color: UIColor) {
        super.updatePreferredBackgroundColor(color)
        DispatchQueue.main.async(execute: { [weak self] in
            self?.preferredBackgroundColor = color
        })
    }
    
    @objc func appMovedToBackground() {
        self.liveRenderView.isHidden = true
        phenix.stopBroadcast()
    }
    
    func initBroadcast(isStartBroadcast: Bool = true) {
        let roomAlias = self.storyOptions?.id
        phenix.joinRoom(roomAlias:roomAlias, notificationHandler: onPhenixNotification)
        phenix.initializeForBroadcast(monitorLayer: liveRenderView.layer, roomAlias: roomAlias) { (status) in
            switch status {
            case .ok :
                DispatchQueue.main.async(execute: { [weak self] in
                    defer {
                        SwiftSpinner.hide()
                    }
                    guard let self = self else { return }
                    self.liveRenderView.isHidden = false
                    if isStartBroadcast {
                        self.startAt = Date().millisecondsSince1970
                        self.startBroadcastButtonTapped()
                    }
                })
            default:
                DispatchQueue.main.async(execute: {
                    SwiftSpinner.show("Failed when init broadcast").addTapHandler({
                        SwiftSpinner.hide()
                    })
                })
            }
        }
    }
    
    func updateUIWhenChangeState() {
        DispatchQueue.main.async(execute: { [weak self] in
            guard let self = self else { return }
            self.createLiveInfoView?.isHidden = self.phenix.isBroadcasting == true ? true : false
        })
    }
    
    @objc func leaveRoom() {
        if let storyOptions = self.storyOptions, self.broadcastType == .showcase {
            storyOptions.liveSettings["endAt"] = Date().iso8601()
            storyOptions.liveSettings["isStreaming"] = false
            APIClient.updateShowcase(showcaseId: storyOptions.id, options: storyOptions) { (_) in }
        }

        self.phenix.leaveRoom() { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.broadcastType == .chat {
                    self.navigationController?.popViewController(animated: true)
                } else {
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }
        }
    }
    
    override func endLiveView() {
        var actions: [AlertAction] = []
        let alert: AlertPopupVC
        actions.append(AlertAction(title: "Cancel", handler: nil))
        if self.broadcastType == .chat {
            actions.append(AlertAction(title: "Yes") { [weak self] in
                self?.leaveRoom()
            })
            alert = AlertPopupVC(title: "Are you sure you want to end your Puffsesh?", detail: nil, action: AlertAction(title: "Yes") { [weak self] in
                self?.leaveRoom()
            })
        } else {
            alert = AlertPopupVC(title: "Are you sure you want to end your LIVE stream?",
                                        detail: "You cannot go back to stream again in this same video. You can chat with users for 30 minutes as long as they're still active in the chat",
                                        action: AlertAction(title: "Yes") { [weak self] in
                self?.leaveRoom()
            })
        }
        present(alert, animated: true)
    }
    
    override func streamStart() {
        super.streamStart()
        pulseLabel.isHidden = true
    }
    
    func startBroadcastButtonTapped() {
        if phenix.isBroadcasting == true {
            phenix.stopBroadcast()
            updateUIWhenChangeState()
        } else {
            delegateController?.updateCameraButton(isOn: true)
            phenix.startBroadcast(asPresenter: true, notificationHandler: onPhenixNotification)
        }
    }
    
    @IBAction func switchCameraButtonTapped(_ sender: UIButton) {
        phenix.switchCamera()
    }
    
    override func didPressCamera() {
        super.didPressCamera()
        if phenix.isBroadcasting == false {
            SwiftSpinner.show("Camera starting...").addTapHandler({
                SwiftSpinner.hide()
            })
            phenix.initializeForBroadcast(monitorLayer: liveRenderView.layer) { (status) in
                switch status {
                case .ok :
                    DispatchQueue.main.async(execute: { [weak self] in
                        SwiftSpinner.hide()
                        guard let self = self else { return }
                        self.liveRenderView.isHidden = false
                        self.phenix.startBroadcast( asPresenter: true, notificationHandler: self.onPhenixNotification )
                    })
                default:
                    DispatchQueue.main.async(execute: {
                        SwiftSpinner.show("Failed").addTapHandler({
                            SwiftSpinner.hide()
                        })
                    })
                }
            }
        } else {
            self.liveRenderView.isHidden = true
            phenix.stopBroadcast()
        }
    }
    
    func setUpLiveInfoView() {
        let createLiveInfoVC = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: CreateLiveInfoVC.nameOfClass) as! CreateLiveInfoVC
        createLiveInfoVC.isVC = false
        if let storyOptions = self.storyOptions {
            createLiveInfoVC.storyOptions = storyOptions
        }
        createLiveInfoVC.preferredBackgroundColor = .clear
        createLiveInfoVC.preferredBgContainColor = UIColor.Puffy.Theme.Grayscale.tg3.withAlphaComponent(0.6)
        createLiveInfoVC.didUpdateLiveOptions = { [weak self] storyOptions in
            self?.storyOptions = storyOptions
        }
        addChild(createLiveInfoVC)
        view.addSubview(createLiveInfoVC.view)
        createLiveInfoVC.didMove(toParent: self)
        
        /// Add constraint for this view
        createLiveInfoVC.view.translatesAutoresizingMaskIntoConstraints = false
        createLiveInfoVC.view.topAnchor.constraint(equalTo: view.topAnchor, constant: 15).isActive = true
        createLiveInfoVC.view.bottomAnchor.constraint(equalTo: view.topAnchor, constant: 15).isActive = true
        createLiveInfoVC.view.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
        createLiveInfoVC.view.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -15).isActive = true
        createLiveInfoView = createLiveInfoVC.view
    }
    
    func setUpUI() {
        pulseLabel.text = "Starting..."
        pulseLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        if broadcastType == .showcase {
            setUpLiveInfoView()
        }
        toogleUIForChat()
    }
    
    func updateUI(isLive: Bool) {
        createLiveInfoView?.isHidden = isLive ? true : false
    }
    
    override func updateTimer() {
        super.updateTimer()
    }
}

