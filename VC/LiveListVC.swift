//
//  LiveFeedVC.swift
//  PuffyApp
//
//  Created by Apple2 on 10/23/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import LGButton
import Firebase

class LiveListVC: PuffyVC {
    
    private enum LiveFeedTagSection: Int, CaseIterable {
        case featured, myPuffing, puffsesh
    }
    
    /// UI Components
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var puffSeshButton: LGButton!
    @IBOutlet weak var puffCastButton: LGButton!
    @IBOutlet weak var streamButton: LGButton!
    @IBOutlet weak var filterButton: UIButton!
    
    /// The control to pull to refresh
    private let refreshControl = UIRefreshControl()
    
    /// Listener for new live showcase
    private var listenerForLive: ListenerRegistration? = nil {
        willSet{
            if newValue == nil {
                listenerForLive?.remove()
            }
        }
    }
    private var listenerForPuffsesh: ListenerRegistration? = nil {
        willSet{
            if newValue == nil {
                listenerForPuffsesh?.remove()
            }
        }
    }
    
    var featuredItems: [CommunityItem] = []
    var myPuffingItems: [CommunityItem] = []
    var myPuffseshItems: [SearchUserItem] = []
    
    var isPushingLiveVC = false
    var refreshingQueueNumber = 0 {
        didSet {
            logPrint(message: "Queue number Queue number Queue number Queue number Queue number  = \(refreshingQueueNumber)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        fetchData()
        _addListener()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.isPushingLiveVC = false
    }
    
    deinit {
        listenerForLive = nil
        listenerForPuffsesh = nil
    }
    
    func setUpUI() {
        tableView.register(LiveListTVC.nib(), forCellReuseIdentifier: LiveListTVC.nameOfClass)
        tableView.register(CustomTSH.nib(), forHeaderFooterViewReuseIdentifier: CustomTSH.nameOfClass)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.separatorStyle = .none
        
        let fontName = UIFont.Style.bold.rawValue
        puffCastButton.titleFontName = fontName
        streamButton.titleFontName = fontName
        filterButton.tintColor = UIColor.Puffy.Theme.Grayscale.inverted
        
        puffCastButton.isHidden = (ProfileManager.enableLiveShowcaseSubmission == false)
        streamButton.isHidden = (ProfileManager.enableLiveShowcaseSubmission == false)
        
        // Add Refresh Control to Table View
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        // Configure Refresh Control
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)
    }
   
    func fetchData() {
        refreshingQueueNumber += 1
        let featureItemsFilter = RequestExploreItemsFilter.init(onlyPuffed: false, showcaseTypes: [.live, .puffcast], isJoinable: true)
        APIClient.requestExploreItems(filter: featureItemsFilter) { [weak self] (result) in
            defer {
                self?.refreshingQueueNumber -= 1
            }
            switch result {
            case .success(let data):
                self?.featuredItems = data.feedItems
                self?.tableView.reloadSections(IndexSet(integer: LiveFeedTagSection.featured.rawValue), with: .fade)
            case .failure(_):
                break
            }
        }
        
        refreshingQueueNumber += 1
        let myPuffingItemsFilter = RequestExploreItemsFilter.init(onlyPuffed: true, showcaseTypes: [.live, .puffcast], isJoinable: true)
        APIClient.requestExploreItems(filter: myPuffingItemsFilter) { [weak self] (result) in
            defer {
                self?.refreshingQueueNumber -= 1
            }
            switch result {
            case .success(let data):
                self?.myPuffingItems = data.feedItems
                self?.tableView.reloadSections(IndexSet(integer: LiveFeedTagSection.myPuffing.rawValue), with: .fade)
            case .failure(_):
                break
            }
        }
        
        refreshingQueueNumber += 1
        APIClient.searchProfiles(queryText: "*", sortBy: nil, isLiveChatActive: true) { [weak self] (result) in
            defer {
                self?.refreshingQueueNumber -= 1
            }
            switch result {
            case .success(let data):
                self?.myPuffseshItems = data.searchItems ?? []
                self?.tableView.reloadSections(IndexSet(integer: LiveFeedTagSection.puffsesh.rawValue), with: .fade)
            case .failure(_):
                break
            }
        }
        self.refreshControl.endRefreshing()
    }
    
    private func _addListener() {
        DispatchQueue.global( qos: .background ).asyncAfter(deadline: .now() + .seconds(5), execute: { [weak self] in
            guard let self = self else { return }
            if self.listenerForLive == nil {
                self.listenerForLive = DatabaseManager.sharedInstance.listenForLiveShowcase( updateHandler: self._onLiveShowcaseUpdate )
            }
            if self.listenerForPuffsesh == nil {
                self.listenerForPuffsesh = DatabaseManager.sharedInstance.listenForPuffsesh( updateHandler: self._onLivePuffseshUpdate )
            }
        })
    }
    private func _onLiveShowcaseUpdate(item: CommunityMediaItem, createdBy: String?, type: DocumentChangeType) {
        guard self.refreshingQueueNumber == 0 else { return }
        let featuredIndex = self.featuredItems.firstIndex(where: {$0.mediaItem.mediaId == item.mediaId})
        let myPuffingIndex = self.myPuffingItems.firstIndex(where: {$0.mediaItem.mediaId == item.mediaId})
        var sections = IndexSet()
        if type == .removed {
            if let featuredIndex = featuredIndex {
                self.featuredItems.remove(at: featuredIndex)
                sections.insert(LiveFeedTagSection.featured.rawValue)
            }
            if let myPuffingIndex = myPuffingIndex {
                self.myPuffingItems.remove(at: myPuffingIndex)
                sections.insert(LiveFeedTagSection.myPuffing.rawValue)
            }
            self.tableView.reloadSections(sections, with: .fade)
        } else {
            if let featuredIndex = featuredIndex {
                self.featuredItems[featuredIndex].mediaItem = item
                sections.insert(LiveFeedTagSection.featured.rawValue)
                if let myPuffingIndex = myPuffingIndex {
                    self.myPuffingItems[myPuffingIndex].mediaItem = item
                    sections.insert(LiveFeedTagSection.myPuffing.rawValue)
                }
                self.tableView.reloadSections(sections, with: .fade)
            } else if let createdBy = createdBy {
                APIClient.Users.get(id: createdBy, completion: { (result) in
                    switch result {
                    case .success(let data):
                        let communityItem = CommunityItem(mediaItem: item, communityItemId: "\(createdBy)-\(item.mediaId)", profileDoc: data.profileDoc)
                        self.featuredItems.insert(communityItem, at: 0)
                        if communityItem.user.matchStatus == .match || communityItem.user.matchStatus == .pending {
                            self.myPuffingItems.insert(communityItem, at: 0)
                            sections.insert(LiveFeedTagSection.myPuffing.rawValue)
                        }
                        sections.insert(LiveFeedTagSection.featured.rawValue)
                        self.tableView.reloadSections(sections, with: .fade)
                    case .failure(let error):
                        logPrint(message: "Edit showcase get profile thumbnail failed: \(error.localizedDescription)")
                    }
                })
            }
        }
    }
    private func _onLivePuffseshUpdate( user: SearchUserItem ) {
        guard self.refreshingQueueNumber == 0 else { return }
        if let index = self.myPuffseshItems.firstIndex(where: {$0.userId == user.userId}) {
            if user.isLiveChatActive == false, self.myPuffseshItems.removeSafely(at: index) {
                self.tableView.reloadSections(IndexSet(integer: LiveFeedTagSection.puffsesh.rawValue), with: .fade)
            }
        } else {
            if user.isLiveChatActive == true {
                self.myPuffseshItems.insert(user, at: 0)
                self.tableView.reloadSections(IndexSet(integer: LiveFeedTagSection.puffsesh.rawValue), with: .fade)
            }
        }
    }
    
}

extension LiveListVC {
    
    @objc private func refreshData(_ sender: Any) {
        // Fetch Data
        if self.refreshControl.isRefreshing == false {
            self.refreshControl.beginRefreshing()
        }
        fetchData()
    }
    
    @IBAction func didPressPuffsesh(_ sender: Any) {
        let controller = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: LiveFeedViewController.nameOfClass) as! LiveFeedViewController
        controller.placeholderImageUrl = DefaultsData.profileImage
        controller.roomAlias = DefaultsData.roomAlias
        controller.broadcastType = .chat
        navigationController?.pushViewController(controller, animated: true)
    }
    
    @IBAction func didPressStream(_ sender: Any) {
        let vc = UIStoryboard(name: UIStoryboard.Name.createStory, bundle: nil).instantiateViewController(withIdentifier: CreateStoryVC.nameOfClass) as! CreateStoryVC
        vc.selectedCameraCategory = .stream
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func didPressPuffcast(_ sender: Any) {
        let vc = UIStoryboard(name: UIStoryboard.Name.createStory, bundle: nil).instantiateViewController(withIdentifier: CreateStoryVC.nameOfClass) as! CreateStoryVC
        vc.selectedCameraCategory = .puffcast
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func didPressFilter(_ sender: Any) {
    }
}

extension LiveListVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UIScreen.main.bounds.size.width / 3
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return LiveFeedTagSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionTag = LiveFeedTagSection(rawValue: section)!
        // Dequeue with the reuse identifier
        let header = self.tableView.dequeueReusableHeaderFooterView(withIdentifier: CustomTSH.nameOfClass) as! CustomTSH
        let buttonTitle: String?
        switch sectionTag {
        case .myPuffing:
            buttonTitle = "My Puffing"
        case .puffsesh:
            buttonTitle = "Puffsesh"
        default:
            buttonTitle = "Featured"
        }
        header.setUp("Show All", buttonTitle)
        header.titleLabel.font = UIFont(style: .bold, size: 20)
        header.detailButton?.titleLabel?.font = UIFont(style: .semiBold, size: 16)
        header.detailButton?.setTitleColor(UIColor.Puffy.Green.booger, for: .normal)
        header.backgroundView?.backgroundColor = tableView.backgroundColor
        header.mainView.backgroundColor = tableView.backgroundColor
        header.onPressDetailButton = { [weak self] in
            guard let self = self else { return }
            let vc = UIStoryboard(name: UIStoryboard.Name.live, bundle: nil).instantiateViewController(withIdentifier: LiveSingleListVC.nameOfClass) as! LiveSingleListVC
            vc.title =  header.titleLabel.text
            switch sectionTag {
            case .myPuffing:
                vc.onlyPuffed = true
                vc.liveItems = self.myPuffingItems
                vc.broadCastType = .showcase
            case .puffsesh:
                vc.liveItems = self.myPuffseshItems
            default:
                vc.liveItems = self.featuredItems
                vc.broadCastType = .showcase
            }
            self.pushViewController(vc)
        }
        return header
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionTag = LiveFeedTagSection(rawValue: indexPath.section)!
        let cell = tableView.dequeueReusableCell(withIdentifier: LiveListTVC.nameOfClass, for: indexPath) as! LiveListTVC
        switch sectionTag {
        case .myPuffing:
            cell.liveItems = self.myPuffingItems
        case .puffsesh:
            cell.liveItems = self.myPuffseshItems
        default:
            cell.liveItems = self.featuredItems
        }
        
        cell.didSelectItem = { [weak self] item in
            guard self?.isPushingLiveVC == false else { return }
            self?.isPushingLiveVC = true
            if let item = item as? CommunityItem {
                CommunityItem.storyOptions(from: item) { options in
                    let controller = LiveController.createLiveControler(communityItem: item)
                    controller.storyOptions = options
                    self?.navigationController?.pushViewController(controller, animated: true)
                }
            } else if let item = item as? SearchUserItem {
                let controller = LiveController.createLiveControler(userItem: item)
                self?.navigationController?.pushViewController(controller, animated: true)
            }
        }
        
        return cell
    }
}
