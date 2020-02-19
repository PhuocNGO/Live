//
//  LiveFeedAudienceViewController.swift
//  PuffyApp
//
//  Created by Apple2 on 10/14/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import PhenixSdk

class LiveController: PuffyVC {
    
    static func createLiveControler(communityItem: CommunityItem) -> LiveController {
        let controller: LiveController
        let isHost = (communityItem.userId == ProfileManager.sharedInstance.loggedInUid)
        if isHost, communityItem.mediaItem.showcaseType == .live {
            controller = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: LiveFeedViewController.nameOfClass) as! LiveFeedViewController
        } else {
            controller = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: LiveFeedAudienceViewController.nameOfClass) as! LiveFeedAudienceViewController
            controller.placeholderImageUrl = (communityItem.mediaItem.mediaUrl.mediaType == .video) ? communityItem.mediaItem.thumbnailUrl : communityItem.mediaItem.mediaUrl
        }
        controller.isHost = isHost
        controller.roomAlias = communityItem.mediaItem.roomAlias
        controller.broadcastType = (communityItem.mediaItem.showcaseType == .live) ? .showcase : .puffcast
        return controller
    }
    
    static func createLiveControler(userItem: SearchUserItem) -> LiveController {
        let controller: LiveController
        let isHost = (userItem.roomAlias == DefaultsData.roomAlias)
        if isHost {
            controller = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: LiveFeedViewController.nameOfClass) as! LiveFeedViewController
        } else {
            controller = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: LiveFeedAudienceViewController.nameOfClass) as! LiveFeedAudienceViewController
            controller.placeholderImageUrl = userItem.url?.resizedImageUrl(width: 480)
        }
        controller.isHost = isHost
        controller.roomAlias = userItem.roomAlias
        controller.broadcastType = .chat
        return controller
    }
    
    public var broadcastType: PhenixRoomHelper.BroadcastType = .showcase {
        didSet {
            phenix.broadcastType = broadcastType
        }
    }
    
    internal var phenix: PhenixRoomHelper = PhenixRoomHelper.shared
    
    weak internal var delegateController: PhenixLiveOverlayDelegate? = nil
    weak internal var trailerOverlayVC: LivePlaceHolderOverlayVC? = nil
    
    public var roomAlias: String? = nil
    var members: [ListUser] = []
    var kickedMembers: [ListUser] = []
    var mutedMembers: [ListUser] = []
    var isMuted: Bool = false
    var isHost: Bool = false

    internal var timer = Timer()
    internal var seconds = 0
    var startAt: Int64? = nil
    
    private var messageHistory: [String] = []
    public var placeholderImageUrl: URL? = nil {
        didSet {
            phenix.placeholderImageUrl = placeholderImageUrl
        }
    }
    public var storyOptions: StoryOptions? {
        didSet{
            guard let storyOptions = self.storyOptions else { return }
            self.roomAlias = storyOptions.id
            if self.storyOptions?.showcaseType == .puffcast, let startAt = self.storyOptions?.liveSettings["startAt"] as? Int64, startAt > 0 {
                self.startAt = self.storyOptions?.liveSettings["startAt"] as? Int64
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == LiveChatOverlayVC.nameOfClass {
            delegateController = segue.destination as? LiveChatOverlayVC
            delegateController?.updateChatStatus(isDisabled: storyOptions?.liveSettings["chatsDisable"] as? Bool ?? false)
            delegateController?.didSendMessage = { [weak self] message in
                guard self?.isMuted == false, let roomAlias = self?.roomAlias else { return }
                self?.phenix.sendMessage(roomAlias: roomAlias, message: message)
            }
            delegateController?.didSendCommand = { [weak self] (command: PhenixMessageData.CommandType) in
                guard self?.isMuted == false, let roomAlias = self?.roomAlias else { return }
                self?.phenix.sendCommand(roomAlias: roomAlias, command: command)
            }
            delegateController?.didSendSticker = { [weak self] (id: Int, count: Int) in
                guard self?.isMuted == false, let roomAlias = self?.roomAlias else { return }
                self?.phenix.sendSticker(roomAlias: roomAlias, id: id, count: count)
            }
            delegateController?.didSwitchCamera = { [weak self] in self?.phenix.switchCamera() }
            delegateController?.didPressEnd = { [weak self] in self?.endLiveView() }
            delegateController?.didPressCamera = { [weak self] in
                self?.delegateController?.updateCameraButton(isOn: (self?.phenix.isBroadcasting == true) ? false : true)
                self?.didPressCamera()
            }
            delegateController?.didPressViewer =  { [weak self] in
                self?.didPressViewUsers()
            }
            delegateController?.didPressMicro = { [weak self] in
                guard let self = self else { return }
                self.phenix.switchAudioState()
                self.delegateController?.updateMicroStatus(isMuted: self.phenix.isMuted)
            }
            delegateController?.didPressFlash = { [weak self] in
                guard let self = self else { return }
                self.phenix.switchFlash()
                self.delegateController?.updateFlashStatus(isFlashOn: self.phenix.flashMode == .alwaysOn)
            }
            delegateController?.didChangeBgColor = { [weak self] color in
                self?.updatePreferredBackgroundColor(color)
            }
            delegateController?.didOpenMenu = { [weak self] (userId, userName) in
                self?.openMenu(userId: userId, userName: userName)
            }
            delegateController?.didPressStart = { [weak self] in
                guard self?.phenix.broadcastType == .puffcast, let urls = self?.storyOptions?.liveSettings["streamVideo"] as? [URL], let url = urls.first else { return }
                DispatchQueue.main.async {  [weak self] in
                    self?.trailerOverlayVC?.contentView.isHidden = true
                }
                self?.phenix.startRemoteBroadcast(streamUrl: url.maxResolutionStream())
                self?.startAt = Date().millisecondsSince1970
                guard let storyOptions = self?.storyOptions else { return }
                storyOptions.liveSettings["startAt"] = Date().iso8601()
                storyOptions.liveSettings["isStreaming"] = true
                APIClient.updateShowcase(showcaseId: storyOptions.id, options: storyOptions, completion: { (_) in })
            }
            delegateController?.updateChatStatus(isDisabled: self.storyOptions?.liveSettings["chatsDisabled"] as? Bool ?? false)
        } else if segue.identifier == LivePlaceHolderOverlayVC.nameOfClass {
            trailerOverlayVC = segue.destination as? LivePlaceHolderOverlayVC
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        hideNavigationBar()
        self.runTimer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        phenix.leaveRoom()
        UIApplication.shared.isIdleTimerDisabled = false
        UIDevice.current.setValue(Int(UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
        timer.invalidate()
    }
    
    /// Override function
    func showPlaceHolderContainer(_ url: URL?, message: String? = nil) {
        self.delegateController?.updateForChatU(isCameraOn: false)
    }
    
    func didPressCamera() {}
    func switchAudioState(isEnable: Bool) {}
    func streamStart() {}
    func endLiveView() {}
    func updatePreferredBackgroundColor(_ color : UIColor) {}
    func didPressViewUsers() {
        let role = ProfileManager.Role(rawValue: DefaultsData.profileRole)
        guard role.contains(.admin) || self.isHost || self.phenix.isHost else { return }
        let tabVC = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: LiveViewersTabVC.nameOfClass) as! LiveViewersTabVC
        tabVC.sections = ["Viewers" : self.members, "Kicked Users" : self.kickedMembers]
        tabVC.didSelectUser =  { [weak self] (user) in
            guard user.userId != ProfileManager.sharedInstance.loggedInUid else { return }
            self?.dismissPopupSheet()
            self?.openMenu(userId: user.userId, userName: user.username ?? "")
        }
        presentSheet(with: tabVC, height: self.view.bounds.height / 2, masksBackground: true, draggable: true)
    }
    
    func onPhenixNotification( notification: PhenixRoomHelper.PhenixNotification ) {
        guard let type = notification.type else {
            showPlaceHolderContainer(self.placeholderImageUrl)
            return
        }
        switch type {
        case .message:
            if let messages = notification.messages {
                guard messages.count > 0 else { return }
                // NOTE first we figure out how many new messages we have
                let last = 0
                var first = 0
                if messageHistory.count > 0 {
                    for message in messages {
                        if let mid = message.getId() {
                            if messageHistory.contains(mid) {
                                break
                            }
                            first = first + 1
                        }
                    }
                } else {
                    first = messages.count
                }
                // NOTE: there's a known phenix but that there's a race condition where we get a join command before the history is compiled; so we need to check to make sure we don't have a problem
                if messages.count - first > messageHistory.count {
                    first = messages.count
                }
                // NOTE: now we work backwards through the list for only the new messages
                var hostLeft = false
                for i in stride( from: (first - 1), through: last, by: -1 ) {
                    let message = messages[ i ]
                    if let mid = message.getId() {
                        if messageHistory.contains(mid) {
                            continue
                        }
                        messageHistory.append(mid)
                        if let data = message.messageData() {
                            switch data.type {
                            case .message:
                                data.timestamp = message.messageTimestamp()
                                self.delegateController?.addMessage(data)
                            case .command:
                                switch data.command {
                                case .like:
                                    self.delegateController?.sendLike(fromHost: data.isHost)
                                case .join:
                                    /*
                                    guard phenix.isHost == true || self.kickedMembers.contains(where: { $0.userId == data.userId }) == false else {
                                        if let roomAlias = self.roomAlias {
                                            self.phenix.sendCommand(roomAlias: roomAlias, command: .kick, userId: data.userId)
                                        }
                                        return
                                    }
                                     */
                                    if self.members.contains(where: { $0.userId == data.userId }) == false {
                                        members.append(ListUser(username: data.userName, thumbnailUrl: data.imageUrl, userId: data.userId))
                                    }
                                    if data.isHost {
                                        hostLeft = false
                                    }
                                case .left:
                                    members.removeAll(where: { $0.userId == data.userId })
                                    if data.isHost {
                                        hostLeft = true
                                    }
                                case .sticker:
                                    logPrint(level: .info, message: "PhenixNotification sticker")
                                    self.delegateController?.sendSticker(data: data)
                                case .none:
                                    if phenix.isHost == false {
                                        self.startAt = data.timestamp?.millisecondsSince1970
                                    }
                                case .kick:
                                    guard phenix.isHost == false, data.userId == ProfileManager.sharedInstance.loggedInUid else { return }
                                    DispatchQueue.main.async {
                                        self.showBannerPopup(text: "You were kicked out by broadcaster.", color: UIColor.Puffy.Purple.periwinkle)
                                    }
                                    self.phenix.leaveRoom() { [weak self] in
                                        self?.showPlaceHolderContainer(self?.placeholderImageUrl)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: { [weak self] in
                                            self?.navigationController?.popViewController(animated: true)
                                        })
                                    }
                                case .mute:
                                    guard phenix.isHost == false, data.userId == ProfileManager.sharedInstance.loggedInUid else { return }
                                    isMuted = true
                                case .unmute:
                                    guard data.userId == ProfileManager.sharedInstance.loggedInUid else { return }
                                    isMuted = false
                                }
                                
                            }
                        }
                    }
                }
                if self.phenix.isHost == false, hostLeft {
                    self.phenix.leaveRoom() { [weak self] in
                        self?.showPlaceHolderContainer(self?.placeholderImageUrl)
                        DispatchQueue.main.async {
                            self?.navigationController?.popViewController(animated: true)
                        }
                    }
                }
            }
        case .status:
            if notification.status == .ok {
                //self.runTimer()
                if self.phenix.streamId?.isEmpty == false  {
                    DispatchQueue.main.async(execute: { [weak self] in
                        self?.streamStart()
                        if self?.phenix.broadcastType == .chat {
                            self?.delegateController?.updateForChatU(isCameraOn: false)
                        } else {
                            self?.delegateController?.updateForChatU(isCameraOn: (self?.phenix.isHost ?? false ? false : true))
                        }
                    })
                } else if phenix.broadcastType == .puffcast, self.isHost {
                    self.delegateController?.enableStartButton(isOn: true)
                }
            } else {
                showPlaceHolderContainer(self.placeholderImageUrl)
            }
        case .ended:
            if notification.reason == .failed || notification.reason == .appBackground {
                showPlaceHolderContainer(self.placeholderImageUrl, message: "Broadcaster is having some problem with connection.")
            } else {
                defer {
                    showPlaceHolderContainer(self.placeholderImageUrl)
                }
                if self.phenix.broadcastType == .puffcast {
                    guard let options = self.storyOptions else { return }
                    options.liveSettings["endAt"] = Date().iso8601()
                    options.liveSettings["isStreaming"] = false
                    storyOptions = options
                    APIClient.updateShowcase(showcaseId: options.id, options: options) { (_) in }
                }
            }
        case .host:
            // update UI/UX that host has joined (if this person is not the host)
            if startAt == nil, self.phenix.isHost {
                startAt = Date().millisecondsSince1970
            }
            logPrint(level: .info, message: "PhenixNotification host joined: \(notification.online)")
        case .videoState:
            if notification.state != .enabled {
                self.delegateController?.updateForChatU(isCameraOn: false)
                showPlaceHolderContainer(self.placeholderImageUrl)
            } else {
                DispatchQueue.main.async(execute: { [weak self] in
                    self?.runTimer()
                    self?.streamStart()
                })
                delegateController?.updateForChatU(isCameraOn: (self.phenix.isHost ? false : true))
            }
            logPrint(level: .info, message: "PhenixNotification videoState changed: \(notification.state.rawValue)")
        case .audioState:
            self.switchAudioState(isEnable: notification.state == .enabled ? true : false)
            logPrint(level: .info, message: "PhenixNotification audioState changed: \(notification.state.rawValue)")
        case .audienceSize:
            logPrint(level: .info, message: "PhenixNotification audienceSize changed: \(notification.size)")
            if notification.size == 1, self.phenix.isPresenter == false, self.phenix.broadcastType != .chat {
                showPlaceHolderContainer(self.placeholderImageUrl)
            }
            self.delegateController?.setViewersNumber(numb: notification.size)
            
            guard let startAt = self.startAt else { return }
            if self.phenix.isHost || self.phenix.isPresenter {
                self.phenix.sendHostStartedTime(timestamp: startAt)
            }
        }
    }

    /// Others function
    func openMenu(userId: String, userName: String) {
        view.endEditing(true)
        guard userId != ProfileManager.sharedInstance.loggedInUid else { return }

        var actions: [AlertSheetAction] = []
        
        //// TODO: disable for now, because it abruptly ends the stream
        /*
         alert.addAction(UIAlertAction(title: "View Profile", style: .default) { [weak self] (_) in
         guard let comment = self?.comment else { return }
         let vc = UserProfileVC.create(userId: comment.userId)
         self?.parentViewController?.navigationController?.pushViewController(vc, animated: true)
         })
         */
        
        actions.append(AlertSheetAction(style: .block) { [weak self] in
            guard let self = self else { return }
            BlockManager.sharedInstance.showBlockPrompt(userId: userId, userName: userName, parentVC: self)
        })
        
        actions.append(AlertSheetAction(style: .report) { [weak self] in
            let contentId = userId
            let vc = ReportFormVC(contentId: contentId, contentType: .users, contentDescription: userName) { [weak self](_) in
                self?.showReportSuccessPopup()
            }
            self?.navigationController?.pushViewController(vc, animated: true)
        })
        
        let role = ProfileManager.Role(rawValue: DefaultsData.profileRole)
        if role.contains(.admin) || self.isHost || self.phenix.isHost {
            actions.append(AlertSheetAction(style: .kickUser) { [weak self] in
                let alert = AlertPopupVC(title: "Do you want to kick out this viewer?", detail: nil, action: AlertAction(title: "Kick Out") {
                    guard let self = self, let roomAlias = self.roomAlias else { return }
                    self.phenix.sendCommand(roomAlias: roomAlias, command: .kick, userId: userId)
                    if let index = self.members.firstIndex(where: { $0.userId == userId }) {
                        self.kickedMembers.append(self.members[index])
                        self.members.removeSafely(at: index)
                    }
                })
                self?.present(alert, animated: true)
            })
            
            let muteIndex = self.mutedMembers.firstIndex(where: {$0.userId == userId})
            actions.append(AlertSheetAction(title: (muteIndex == nil) ? "Mute" : "Unmute", style: .mute) { [weak self] in
                guard let roomAlias = self?.roomAlias else { return }
                if let muteIndex = muteIndex {
                    self?.mutedMembers.removeSafely(at: muteIndex)
                    self?.phenix.sendCommand(roomAlias: roomAlias, command: .unmute, userId: userId)
                } else {
                    let alert = AlertPopupVC(title: "Do you want to mute this viewer?", detail: nil, action: AlertAction(title: "Mute") {
                        guard let self = self else { return }
                        if let index = self.members.firstIndex(where: { $0.userId == userId }) {
                            self.mutedMembers.append(self.members[index])
                            self.phenix.sendCommand(roomAlias: roomAlias, command: .mute, userId: userId)
                            self.phenix.sendMessage(roomAlias: roomAlias, message: "Broadcaster muted \(self.members[index].username ?? String("someone"))")
                        }
                    })
                    self?.present(alert, animated: true)
                 }
            })
        }
        
        let alertSheet = AlertSheetVC(header: nil, actions: actions)
        present(alertSheet, animated: true)
    }
    
    func toogleUIForChat() {
        guard self.broadcastType == .chat else { return }
        preferredBackgroundColor = DefaultsData.defaultChatRoomColor
        trailerOverlayVC?.view.isHidden = true
        delegateController?.updateForChatU(isCameraOn: false)
    }
    
    func updateUIForAudience() {
        guard self.phenix.isPresenter == false else { return }
        delegateController?.updateForAudienceUI()
    }
    
    @objc func updateTimer() {
        if let startAt = self.startAt {
            let seconds = Int(Date().millisecondsSince1970 - startAt)/1000
            self.delegateController?.updateTimeLabel(seconds: seconds)
        }
    }
    
    func runTimer() {
        timer.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(updateTimer)), userInfo: nil, repeats: true)
    }
}

