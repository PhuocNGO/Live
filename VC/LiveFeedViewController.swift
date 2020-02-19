//
//  LiveFeedViewController.swift
//  PuffyApp
//
//  Created by Apple2 Li on 10/9/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import PhenixSdk
import SwiftSpinner

class LiveFeedViewController: UIViewController {

    @IBOutlet weak var liveRenderView: UIView!
    @IBOutlet weak var startBroadcastButton: UIButton!
    @IBOutlet weak var chatButton: UIButton!
    @IBOutlet weak var viewerButton: UIButton!
    @IBOutlet weak var viewerNumberLabel: UILabel!
    @IBOutlet weak var timeDurationLabel: UILabel!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var endButton: UIButton!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var pulseLabel: UILabel!
    
    private weak var createLiveInfoView: UIView?
    
    var timer = Timer()
    var countDown = 10
    var seconds = 0
    
    private var phenix: PhenixRoomHelper = PhenixRoomHelper()
    public var storyOptions: StoryOptions?
    
    public var roomId: String {
        get { return self.phenix.roomId }
        set { self.phenix.roomId = newValue }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        
        // Do any additional setup after loading the view.
        SwiftSpinner.show("Connecting")
        if let storyOptions = self.storyOptions, let data = storyOptions.image?.pngData() {
            APIClient.postShowcase(data: data, options: storyOptions) { [weak self] (result) in
                switch result {
                case .success (let data):
                    self?.roomId = data.showcaseId
                    self?.storyOptions?.id = data.showcaseId
                    self?.initBroadcast()
                case .failure(let error):
                    SwiftSpinner.show(error.localizedDescription)
                }
            }
        } else {
            self.initBroadcast()
        }
    }
    
    func initBroadcast() {
        phenix.initializeForBroadcast(monitorLayer: liveRenderView.layer, previewLayer: nil) { (status) in
            SwiftSpinner.hide()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.updateUI(isLive: true)
                self.countDownTimer()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        phenix.shutdown()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func setUpLiveInfoView() {
        let createLiveInfoVC = UIStoryboard(name: "LiveFeedVC", bundle: nil).instantiateViewController(withIdentifier: CreateLiveInfoVC.nameOfClass) as! CreateLiveInfoVC
        if let storyOptions = self.storyOptions {
            createLiveInfoVC.storyOptions = storyOptions
        }
        createLiveInfoVC.preferredBgColor = UIColor.Puffy.Theme.Grayscale.tg3.withAlphaComponent(0.6)
        createLiveInfoVC.didUpdateLiveOptions = { [weak self] storyOptions in
            self?.storyOptions = storyOptions
        }
        addChild(createLiveInfoVC)
        view.addSubview(createLiveInfoVC.view)
        createLiveInfoVC.didMove(toParent: self)
        
        /// Add constraint for this view
        createLiveInfoVC.view.translatesAutoresizingMaskIntoConstraints = false
        createLiveInfoVC.view.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: 10).isActive = true
        createLiveInfoVC.view.bottomAnchor.constraint(equalTo: bottomView.topAnchor, constant: 0).isActive = true
        createLiveInfoVC.view.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 15).isActive = true
        createLiveInfoVC.view.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -15).isActive = true
        createLiveInfoView = createLiveInfoVC.view
    }
    
    func setUpUI() {
        endButton.clipsToBounds = true
        endButton.layer.cornerRadius = 3
        
        pulseLabel.text = "\(self.countDown)"
        setUpLiveInfoView()
        
        startBroadcastButton.backgroundColor = UIColor.Puffy.Theme.Grayscale.inverted.withAlphaComponent(0.5)
        startBroadcastButton.clipsToBounds = true
        startBroadcastButton.layer.cornerRadius = startBroadcastButton.frame.width / 2
    }

    @IBAction func startBroadcastButtonTapped(_ sender: UIButton) {
        self.timeDurationLabel.isHidden = false
        if phenix.isLive {
            timer.invalidate()
            phenix.stopPublish()
            PuffyAnalytics.logEvent(eventName: .tapped_stop_live_feed)
            startBroadcastButton.setImage(#imageLiteral(resourceName: "playButton"), for: .normal)
            createLiveInfoView?.isHidden = false
        } else {
            runTimer()
            phenix.startBroadcast { [weak self] (streamId) in
                guard let self = self, let storyOptions = self.storyOptions else { return }
                storyOptions.liveSettings["streamId"] = streamId
                storyOptions.liveSettings["startAt"] = TimeInterval(NSDate().timeIntervalSince1970)
                self.storyOptions = storyOptions
                APIClient.updateShowcase(showcaseId: storyOptions.id, options: storyOptions, completion: { _ in })
            }
            PuffyAnalytics.logEvent(eventName: .tapped_start_live_feed)
            startBroadcastButton.setImage(#imageLiteral(resourceName: "pauseWhiteSmall"), for: .normal)
            createLiveInfoView?.isHidden = true
        }
    }
    
    func updateUI(isLive: Bool) {
        startBroadcastButton.setImage(isLive ? #imageLiteral(resourceName: "pauseWhiteSmall") : #imageLiteral(resourceName: "playButton"), for: .normal)
        createLiveInfoView?.isHidden = isLive ? true : false
    }

    @IBAction func endStreamButtonTapped(_ sender: UIButton) {
        let action = UIAlertAction(title: "Yes", style: .default) { [weak self] (_) in
            guard let self = self else { return }
            let vc = UIStoryboard(name: "LiveFeedVC", bundle: nil).instantiateViewController(withIdentifier: CreateLiveInfoVC.nameOfClass) as! CreateLiveInfoVC
            if let options = self.storyOptions {
                options.liveSettings["endAt"] = TimeInterval(NSDate().timeIntervalSince1970)
                vc.storyOptions = options
            }
            self.navigationController?.pushViewController(vc, animated: true)
        }
        self.presentAlert(title: "Are you sure you want to end your LIVE stream?", detail: "You cannot go back to stream again in this same video. You can chat with users for 30 minutes as long as they're still active in the chat.", action: action)
    }
    
    @IBAction func flashButtonTapped(_ sender: Any) {
        phenix.switchFlash()
        flashButton.setBackgroundColor(phenix.flashMode == .alwaysOff ? UIColor.Puffy.Theme.Grayscale.tg1.withAlphaComponent(0.5) : .clear, for: .normal)
    }
    
    @IBAction func switchCameraButtonTapped(_ sender: UIButton) {
        phenix.switchCamera()
    }
    
    @IBAction func switchAudioButtonTapped(_ sender: UIButton) {
        phenix.switchAudioState()
        muteButton.setBackgroundColor(phenix.isMuted ? UIColor.Puffy.Theme.Grayscale.tg1.withAlphaComponent(0.5) : .clear, for: .normal)
    }
    
    @IBAction func chatButtonTapped(_ sender: Any) {
        
    }
    
    @IBAction func viewerButtonTapped(_ sender: Any) {
        //present list of viewers
    }
    
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(updateTimer)), userInfo: nil, repeats: true)
    }
    
    func countDownTimer() {
        if timer.isValid {
            timer.invalidate()
        }
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(addPulse),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    @objc func addPulse() {
        if countDown <= 1 {
            timer.invalidate()
            pulseLabel.isHidden = true
            startBroadcastButtonTapped(startBroadcastButton)
        } else {
            countDown -= 1
            pulseLabel.text = "\(countDown)"
        }
    }
    
    @objc func updateTimer() {
        seconds += 1
        timeDurationLabel.text = String(time: TimeInterval(seconds)).trimmingCharacters(in: .whitespaces)
    }
}
