//
//  LiveOverlayViewController.swift
//  PuffyApp
//
//  Created by Apple2 on 11/5/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import LGButton
import Spring
import AMPopTip

class LiveChatOverlayVC: UIViewController, PhenixLiveOverlayDelegate {
    /// Views
    @IBOutlet weak var textField: UITextField! {
        didSet {
            textField.layer.cornerRadius = 15.5
            let placeholderAttributes = [NSAttributedString.Key.foregroundColor: textField.textColor ?? .white]
            let attributedPlaceholder = NSAttributedString(string: "Type something", attributes: placeholderAttributes)
            textField.attributedPlaceholder = attributedPlaceholder
        }
    }
    @IBOutlet weak var inputContainer: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emitterView: WaveEmitterView!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var moreActionButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var commentButton: UIButton!
    @IBOutlet weak var stickerButton: UIButton!
    @IBOutlet weak var likeButton: DesignableButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var viewerNumbers: UIButton!
    @IBOutlet weak var stickerArea: StickerDisplayArea!
    @IBOutlet weak var gifImageView: UIImageView!
    @IBOutlet weak var startButton: UIButton!
    
    /// StackView
    @IBOutlet weak var topButtonStackView: UIStackView!
    @IBOutlet weak var moreButtonStackView: UIStackView!
    @IBOutlet weak var switchCameraStackView: UIStackView!
    
    /// Constraints
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomRightButtonsLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var startVideoHeightConstraint: NSLayoutConstraint!
    
    /// Flags
    var isFlashOn: Bool  = false
    var isMuted: Bool    = false
    var isCameraOn: Bool = false {
        didSet {
            cameraButton?.setImage(isCameraOn ? UIImage(named: "Camera-off") : UIImage(named: "Camera-on"), for: .normal)
            moreActionButton?.setImage(isCameraOn ? UIImage(named: "more_icon") : UIImage(named: "share_icon"), for: .normal)
            moreActionButton?.isEnabled = isCameraOn
            switchCameraButton?.setImage(isCameraOn ? UIImage(named: "swap_camera_icon") : UIImage(named: "paint_icon"), for: .normal)
        }
    }
    
    private var originalConstraint: CGFloat = 0
    private var originalTableViewTopConstraint: CGFloat = 0
    
    /// Attributes, Callback
    private var comments: [PhenixMessageData] = []
    var didSendMessage: ((String)->Void)?
    var didSendSticker: ((Int,Int)->Void)?
    var didSendCommand: ((PhenixMessageData.CommandType)->Void)?
    var didPressEnd: (()->Void)?
    var didSwitchCamera: (()->Void)?
    var didPressCamera: (()->Void)?
    var didPressFlash: (()->Void)?
    var didPressMicro: (()->Void)?
    var didPressViewer: (()->Void)?
    var didChangeBgColor: ((UIColor) -> Void)?
    var didPressKick: ((String)->Void)?
    var didPressMute: ((String)->Void)?
    var didOpenMenu: ((String, String) -> Void)?
    var didPressStart: (() -> Void)?
    
    var chatsDisabled: Bool = false {
        didSet {
            commentButton?.isHidden = chatsDisabled
            updateChatView(isHidden: chatsDisabled)
        }
    }
    lazy private var moreActionsPopTip = PopTip()
    lazy private var shownPopTip: PopTip? = nil
    
    let heartPurple = #imageLiteral(resourceName: "heart_purple_icon").resizedImage(newWidth: 20)
    let heartGreen = #imageLiteral(resourceName: "heart_green_icon").resizedImage(newWidth: 20)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ResourcesManager.shared.requestWith(tag: ResourcesTag.LiveGif.rawValue, onSuccess: { }) { (_) in }
        
        let textFieldSwipeDownGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(handleTextViewSwipeDown(_:)))
        textFieldSwipeDownGestureRecognizer.direction = [.down]
        textField.addGestureRecognizer(textFieldSwipeDownGestureRecognizer)
        
        textField.delegate = self
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: textField.frame.height))
        textField.leftViewMode = .always
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.rowHeight = UITableView.automaticDimension
        
        endButton.layer.cornerRadius = 5
        timeLabel.adjustsFontSizeToFitWidth = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        
        commentButton?.isHidden = chatsDisabled
        updateChatView(isHidden: chatsDisabled)
        
        moreActionsPopTip.shouldDismissOnTapOutside = true
        moreActionsPopTip.shouldDismissOnTap = false
        moreActionsPopTip.shouldCancelTouchesInViewOnTapOutside = false
        
        switchCameraButton.imageView?.contentMode = .scaleAspectFit
        
        /// TODO: hide until  we have share function for LIVE
        moreActionButton.isEnabled = isCameraOn
        
        startButton.layer.cornerRadius = 5
        startButton.backgroundColor = UIColor.Puffy.Green.booger
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShowNotification), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHideNotification), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        
        originalConstraint = bottomLayoutConstraint.constant
        updateTopContentInset()
        tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        textField.resignFirstResponder()
    }
    
    @objc private func handleTextViewSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }
        textField.resignFirstResponder()
    }
    
    @objc func appMovedToBackground() {
        self.updateCameraButton(isOn: false)
    }
    
    @objc func keyboardWillShowNotification(notification: NSNotification) {
        updateFrameWithKeyboard(notification: notification, willShow: true)
    }
    
    @objc func keyboardWillHideNotification(notification: NSNotification) {
        updateFrameWithKeyboard(notification: notification, willShow: false)
    }
    
    fileprivate func updateTopContentInset() {
        let insetTop = self.tableView.bounds.height - self.tableView.contentSize.height
        self.tableView.contentInset.top = insetTop < 0 ? 0 : insetTop
        if self.comments.count > 0 {
            self.tableView.safelyScroll(to: IndexPath(row: self.comments.count - 1, section: 0), at: .bottom, animated: true)
        }
    }
    
    func updateFrameWithKeyboard(notification: NSNotification, willShow: Bool) {
        let userInfo = notification.userInfo!
        
        let animationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as! NSNumber).doubleValue
        let keyboardEndFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let convertedKeyboardEndFrame = view.convert(keyboardEndFrame, from: view.window)
        
        let constant: CGFloat
        if willShow {
            let bottomSafeArea: CGFloat
            if #available(iOS 11.0, *) {
                bottomSafeArea = view.safeAreaInsets.bottom
            } else {
                bottomSafeArea = bottomLayoutGuide.length
            }
            constant = view.bounds.maxY - convertedKeyboardEndFrame.minY - bottomSafeArea
            bottomRightButtonsLeadingConstraint.constant = 0
        } else {
            constant = originalConstraint
            bottomRightButtonsLeadingConstraint.constant = 135
        }
        bottomLayoutConstraint.constant = constant
        
        let newTableViewTopConstraint = self.originalTableViewTopConstraint - constant
        self.tableViewTopConstraint.constant = (newTableViewTopConstraint > 0) ? newTableViewTopConstraint : 0
        
        self.view.layoutIfNeeded()
        UIView.animate(withDuration: animationDuration, delay: 0.0, options: .beginFromCurrentState, animations: { [weak self] in
            self?.updateTopContentInset()
            }, completion: nil )
    }
    
    func initMessage(_ messages: [PhenixMessageData]) {
        self.comments = messages
        DispatchQueue.main.async(execute: { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            self.updateTopContentInset()
        })
    }
    
    public func addMessage(_ message: PhenixMessageData) {
        self.comments.append(message)
        DispatchQueue.main.async(execute: { [weak self] in
            guard let self = self else { return }
            
            UIView.setAnimationsEnabled(false)
            self.tableView.reloadSections(IndexSet(integer: 0), with: .fade)
            self.updateTopContentInset()
            UIView.setAnimationsEnabled(true)
            
            let rawMessage = String(message.message.filter { !" \n\t\r".contains($0) })
            LiveGif.dictionary.keys.forEach({ (key) in
                if rawMessage.lowercased().range(of: key) != nil {
                    self.loadGif(key, name: LiveGif.dictionary[key]?.randomElement())
                }
            })
        })
    }
    
    private func loadGif(_ key: String, name: String?) {
        guard let name = name else { return }
        ResourcesManager.shared.requestWith(tag: key, onSuccess: { [weak self] in
            self?.gifImageView.setGifImage(UIImage(gifName: name), manager: .defaultManager, loopCount: 1)
        }) { (error) in }
    }
    
    func sendLike(fromHost: Bool = false) {
        DispatchQueue.main.async(execute: { [weak self] in
            guard let self = self else { return }
            self.emitterView.emitImage(fromHost ? self.heartGreen : self.heartPurple)
        })
    }
    
    
    func updateForChatU(isCameraOn: Bool) {
        DispatchQueue.main.async { [weak self] in
            // update the tableView frame
            guard let self = self else { return }
            self.tableViewTopConstraint.constant = isCameraOn ? (self.tableView.bounds.height - 200) : 0
            self.originalTableViewTopConstraint = self.tableViewTopConstraint.constant
            self.updateTopContentInset()
        }
    }
    
    func sendSticker(data: PhenixMessageData) {
        DispatchQueue.main.async { [weak self] in
            let event = StickerEvent(data: data)
            self?.stickerArea.pushGiftEvent(event)
        }
    }
    
    func updateForAudienceUI() {
        //moreActionButton.isHidden = true
        //switchCameraButton.isHidden = true
        cameraButton.isHidden = true
        endButton.setTitle("Leave", for: .normal)
    }
    
    func updateViewersNumber(numb: Int) {
        DispatchQueue.main.async(execute: { [weak self] in
            var newNumb = numb
            if let text = self?.viewerNumbers.titleLabel?.text, let previousNumb = Int(text) {
                newNumb += previousNumb
            }
            self?.viewerNumbers.setTitle("\(newNumb > 0 ? newNumb : 0)", for: .normal)
        })
    }
    
    func setViewersNumber(numb: Int) {
        DispatchQueue.main.async(execute: { [weak self] in
            self?.viewerNumbers.setTitle("\(numb)", for: .normal)
        })
    }
    
    func updateCameraButton(isOn: Bool) {
        self.isCameraOn = isOn
    }
    
    func updateFlashButton(isOn: Bool) {
    }
    
    func updateTimeLabel(seconds: Int) {
        timeLabel.isHidden = (seconds <= 0)
        timeLabel.text = String(time: TimeInterval(seconds)).trimmingCharacters(in: .whitespaces)
    }
    
    func updateMicroStatus(isMuted: Bool) {
        self.isMuted = isMuted
    }
    
    func updateFlashStatus(isFlashOn: Bool) {
        self.isFlashOn = isFlashOn
    }
    
    private func endToolUse() {
        if shownPopTip != moreActionsPopTip {
            moreActionsPopTip.hide(forced: true)
        }
    }
    
    func enableStartButton(isOn: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.startButton.isHidden = (isOn == false)
            self?.startVideoHeightConstraint.constant = (isOn == false) ? 0 : 30
        }
    }
}

extension LiveChatOverlayVC {
    
    /// Top buttons
    @IBAction func endButtonTapped(_ sender: Any) {
        didPressEnd?()
    }
    
    @IBAction func switchCameraButtonTapped(_ sender: Any) {
        if self.isCameraOn {
            didSwitchCamera?()
        } else {
            guard !moreActionsPopTip.isVisible else {
                moreActionsPopTip.hide()
                return
            }
            
            let themeView = LiveSelectThemeView(frame: CGRect(x: 0, y: 0, width: 230, height: 100))
            themeView.didSelectColor = { [weak self] color in
                self?.moreActionsPopTip.hide()
                self?.didChangeBgColor?(color)
                DefaultsData.defaultChatRoomColor = color
            }
            
            let sourceFrame = view.convert(switchCameraButton.frame, from: switchCameraStackView)
            moreActionsPopTip.bubbleColor = .white
            moreActionsPopTip.show(customView: themeView, direction: .down, in: view, from: sourceFrame)
            shownPopTip = moreActionsPopTip
            endToolUse()
        }
    }
    
    @IBAction func cameraButtonTapped(_ sender: Any) {
        didPressCamera?()
    }
    
    @IBAction func moreActionButtonTapped(_ sender: Any) {
        guard self.isCameraOn else {
            /// TODO: Share button tap here
            
            var actions: [AlertSheetAction] = []

            actions.append(AlertSheetAction(style: .share) {
                
            })
            actions.append(AlertSheetAction(style: .copyLink) {
                
            })

            return
        }
        
        guard !moreActionsPopTip.isVisible else {
            moreActionsPopTip.hide()
            return
        }
        
        let viewSize: CGFloat = 150
        let viewSpacing: CGFloat = 0
        let subviews: [UIView]
        
        let microGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(microButtonTapped))
        let microView = LiveMoreActionView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        microView.image = isMuted ? #imageLiteral(resourceName: "mic") : #imageLiteral(resourceName: "micOff")
        microView.text = isMuted ? "Turn On Mic" : "Turn Off Mic"
        microView.addGestureRecognizer(microGestureRecognizer)
        
        let flashGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(flashButtonTapped))
        let flashView = LiveMoreActionView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        flashView.image = isFlashOn ? #imageLiteral(resourceName: "flashWhiteOff") : #imageLiteral(resourceName: "flashWhite")
        flashView.text = isFlashOn ? "Flash Off" : "Flash On"
        flashView.addGestureRecognizer(flashGestureRecognizer)
        
        subviews = [flashView, microView]
        
        let stackViewHeight = (40 * CGFloat(subviews.count)) + (viewSpacing * CGFloat(subviews.count - 1))
        let stackView = UIStackView(frame: CGRect(x: 0, y: 0, width: viewSize, height: stackViewHeight))
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fillEqually
        stackView.spacing = viewSpacing
        for subview in subviews {
            stackView.addArrangedSubview(subview)
        }
        
        let sourceFrame = view.convert(moreActionButton.frame, from: moreButtonStackView)
        moreActionsPopTip.bubbleColor = UIColor.Puffy.PuffSesh.t3
        moreActionsPopTip.show(customView: stackView, direction: .down, in: view, from: sourceFrame)
        shownPopTip = moreActionsPopTip
        endToolUse()
    }
    
    @IBAction func viewerButtonTapped(_ sender: Any) {
        didPressViewer?()
    }
    
    @IBAction private func startButtonTapped() {
        enableStartButton(isOn: false)
        didPressStart?()
    }
    
    /// Bottom buttons
    @IBAction func likeButtonTapped(_ sender: Any) {
        // NOTE: we let phenix message observer send like
        didSendCommand?(.like)
    }
    
    @IBAction func chatButtonTapped(_ sender: Any) {
        updateChatView(isHidden: !tableView.isHidden)
        commentButton.setImage(UIImage(named: tableView.isHidden ?  "chatEnableIcon" : "chatDisabledIcon"),
                               for: .normal)
    }
    
    @IBAction func stickerButtonTapped(_ sender: Any) {
        /// To open sticker view.
        //        let vc =  UIStoryboard(name: "LiveFeedVC", bundle: nil).instantiateViewController(withIdentifier: GiftChooserVC.nameOfClass) as! GiftChooserVC
        //        vc.didChooseGift = { [weak self] giftId in
        //            self?.didSendSticker?(giftId, 1)
        //        }
        //        vc.modalPresentationStyle = .custom
        //        present(vc, animated: true, completion: nil)
        
        let stickersVC = UIStoryboard(name: UIStoryboard.Name.createStory, bundle: nil).instantiateViewController(withIdentifier: StoryStickersVC.nameOfClass) as! StoryStickersVC
        stickersVC.delegate = self
        let height = view.frame.height * 0.75
        stickersVC.preferredBackgroundColor = .clear
        if let parent = self.parent as? PuffyVC {
            parent.presentSheet(with: stickersVC, height: height)
        }
    }
    
    func updateChatView(isHidden: Bool) {
        tableView?.isHidden = isHidden
        inputContainer?.isHidden = isHidden
        stickerButton?.isHidden = isHidden
        likeButton?.isHidden = isHidden
        emitterView?.isHidden = isHidden
        stickerArea?.isHidden = isHidden
        gifImageView?.isHidden = isHidden
    }
    
    func updateChatStatus(isDisabled: Bool) {
        self.chatsDisabled = isDisabled
    }
    
    @objc private func microButtonTapped() {
        didPressMicro?()
        moreActionsPopTip.hide()
    }
    
    @objc private func flashButtonTapped() {
        didPressFlash?()
        moreActionsPopTip.hide()
    }
}

extension LiveChatOverlayVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let text = textField.text , text != "" {
            didSendMessage?(text)
        }
        textField.text = ""
        return true
    }
}

extension LiveChatOverlayVC: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let comment = comments[indexPath.row]
        let cell: CommentCell
        if let url = URL(string: comment.message), url.mediaType == .photo {
            cell = tableView.dequeueReusableCell(withIdentifier: StickerCommentCell.nameOfClass, for: indexPath) as! StickerCommentCell
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: TextCommentCell.nameOfClass, for: indexPath) as! TextCommentCell
        }
        cell.comment = comment
        cell.didPressSelectCell = { [weak self] (userId, userName) in
            self?.didOpenMenu?(userId, userName)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .clear
    }
}

extension LiveChatOverlayVC : EditStoryProtocol {
    func newStickerSelected(image: UIImage, url: URL?) {
        if let text = url?.absoluteString {
            didSendMessage?(text)
        }
        if let parent = self.parent as? PuffyVC {
            parent.dismissPopupSheet()
        } else {
            self.parent?.dismiss(animated: true, completion: nil)
        }
    }
    
    func onStorySaveCompleted(error: Error?) {}
    
    func onStoryUploadCompleted(error: Error?) {}
    
    func drawingWasChanged(image: UIImage?) {}
    
    func editStoryTextEditingEnded() {}
    
    func editStoryTextWasTapped(textView: EditStoryTextOverlayView) {}
    
    func editStoryOverlayElementWasDragged(sender: UIView, recognizer: UIPanGestureRecognizer) {}
    
    func doesOverlayHaveEdits() -> Bool { return false }
    
}
