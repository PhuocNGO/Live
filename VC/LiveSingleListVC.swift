//
//  LiveSingleListVC.swift
//  PuffyApp
//
//  Created by Apple2 on 11/28/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import Nuke

class LiveSingleListVC: PuffyVC {
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionWidthConstraint: NSLayoutConstraint!
    
    /// The control to pull to refresh
    private let refreshControl = UIRefreshControl()
    var isPushingLiveVC = false
    let defaultImageSize = 480
    let minSpacing: CGFloat = 5
    let numberItemPerRow: CGFloat = 3
    let preheater = ImagePreheater()
    
    var broadCastType: PhenixRoomHelper.BroadcastType = .chat
    var onlyPuffed: Bool = false
    var liveItems: [Any] = [] {
        didSet {
            collectionView?.reloadData()
            collectionView?.setEmptyMessage(liveItems.isEmpty ? "No streaming" : "")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(LiveListCVC.nib(), forCellWithReuseIdentifier: LiveListCVC.nameOfClass)
        collectionView.layer.cornerRadius = 3
        
        // Add Refresh Control to Table View
        if #available(iOS 10.0, *) {
            collectionView.refreshControl = refreshControl
        } else {
            collectionView.addSubview(refreshControl)
        }
        // Configure Refresh Control
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)
        
        if liveItems.isEmpty {
            fetchData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showNavigationBar()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isPushingLiveVC = false
    }
    
    @objc private func refreshData(_ sender: Any) {
        // Fetch Data
        if self.refreshControl.isRefreshing == false {
            self.refreshControl.beginRefreshing()
        }
        fetchData()
    }
    
    private func fetchData() {
        switch broadCastType {
        case .chat:
            if onlyPuffed == true {
                APIClient.requestPuffees(userId: nil, isLiveChatActive: true) { [weak self] (result) in
                    self?.refreshControl.endRefreshing()
                    switch result {
                    case .success(let data):
                        self?.liveItems = data.searchItems ?? []
                    case .failure(_):
                        self?.liveItems = []
                    }
                }
            } else {
                APIClient.searchProfiles(queryText: "*", sortBy: nil, isLiveChatActive: true) { [weak self] (result) in
                    self?.refreshControl.endRefreshing()
                    switch result {
                    case .success(let data):
                        self?.liveItems = data.searchItems ?? []
                    case .failure(_):
                        self?.liveItems = []
                    }
                }
            }
        default:
            let myPuffingItemsFilter = RequestExploreItemsFilter.init(onlyPuffed: onlyPuffed, showcaseTypes: [.live, .puffcast], isJoinable: true)
            APIClient.requestExploreItems(filter: myPuffingItemsFilter) { [weak self] (result) in
                self?.refreshControl.endRefreshing()
                switch result {
                case .success(let data):
                    self?.liveItems = data.feedItems
                case .failure(_):
                    self?.liveItems = []
                }
            }
        }
    }
}

extension LiveSingleListVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return minSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - minSpacing * (numberItemPerRow - 1)) / numberItemPerRow
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return liveItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LiveListCVC.nameOfClass, for: indexPath) as! LiveListCVC
        guard let item = self.liveItems[safe: indexPath.row] else { return cell }
        
        var imageURL: URL? = nil
        if let item = item as? CommunityItem {
            cell.liveStateView.setStream(item)
            cell.userNameLabel.text = item.user.name
            cell.titleLabel.text = item.mediaItem.rawDescription
            imageURL = item.mediaItem.thumbnailUrl
        } else if let item = item as? SearchUserItem {
            cell.liveStateView.setStreamState(.default)
            cell.userNameLabel.text = item.name
            imageURL = item.url?.resizedImageUrl(width: defaultImageSize)
            
            
            //// To let Admin can force disable LIVE CHAT / PUFFSESH no longer working but still online for some reason
            if ProfileManager.Role(rawValue: DefaultsData.profileRole).contains(.admin) {
                let longPress = UILongPressGestureRecognizer(target: self, action: #selector(forceDisableChat(_:)))
                if #available(iOS 11.0, *) {
                    longPress.name = item.userId
                }
                cell.addGestureRecognizer(longPress)
            }
        }
        
        if let imageURL = imageURL {
            UIImage.image(from: imageURL) { (img) in
                cell.imageView?.image = img
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard isPushingLiveVC == false, let item = self.liveItems[safe: indexPath.row] else { return }
        isPushingLiveVC = true
        if let item = item as? CommunityItem {
            CommunityItem.storyOptions(from: item) { [weak self] (options) in
                let controller = LiveController.createLiveControler(communityItem: item)
                controller.storyOptions = options
                self?.navigationController?.pushViewController(controller, animated: true)
            }
        } else if let item = item as? SearchUserItem {
            let controller = LiveController.createLiveControler(userItem: item)
            navigationController?.pushViewController(controller, animated: true)
        }
    }
    
    //// To let Admin can force disable LIVE CHAT / PUFFSESH no longer working but still online for some reason
    @objc func forceDisableChat(_ sender: UILongPressGestureRecognizer) {
        if #available(iOS 11.0, *) {
            guard let userId = sender.name else { return }

            let alert = AlertPopupVC(title: "Are you sure that you want to disable this chat?", detail: nil, action: AlertAction(title: "Disable") { [weak self] in
                APIClient.disableLiveChat(userId: userId)
                self?.liveItems.removeAll(where: { (item) -> Bool in
                    guard let item = item as? SearchUserItem else { return false }
                    return item.userId == userId
                })
                self?.collectionView.reloadData()
            })
            present(alert, animated: true)
        }
    }
}

extension LiveSingleListVC: UICollectionViewDataSourcePrefetching {
    
    func getUrls(_ indexPaths: [IndexPath]) -> [URL] {
        return indexPaths.compactMap { [weak self] (indexPath) -> URL? in
            guard let item = self?.liveItems[safe: indexPath.row] else { return nil }
            var url: URL? = nil
            if let item = item as? CommunityItem {
                url = item.mediaItem.thumbnailUrl
            } else if let item = item as? SearchUserItem {
                url = item.url?.resizedImageUrl(width: defaultImageSize)
            }
            return url
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        preheater.startPreheating(with: getUrls(indexPaths))
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        preheater.stopPreheating(with: getUrls(indexPaths))
    }
}
