//
//  CreateLiveInfoVC.swift
//  PuffyApp
//
//  Created by Apple2 on 10/29/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import UIKit
import SwiftSpinner

fileprivate let tagsCellHeight: CGFloat = 50
fileprivate let captionHeight: CGFloat = 100
fileprivate let bgColor = UIColor(white: 74.0 / 255.0, alpha: 0.6)

class CreateLiveInfoVC : PuffyVC {
    
    @IBOutlet weak var tableView: UITableView!
    /// `statusBarGapFillerView` is used to fill in the gap left in the view when this view controller is being dismissed to show EditStoryVC, which hides its status bar. Hiding the status bar moves this view's navigation bar up, leaving a status bar-sized gap in the main view below the navigation bar during the transition, which `statusBarGapFillerView` fills.
    @IBOutlet weak private var statusBarGapFillerView: UIView! {
        didSet {
            statusBarGapFillerView.backgroundColor = UIColor.Puffy.Theme.Grayscale.mainBackground
        }
    }
    @IBOutlet weak var statusBarGapFillerViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchContainerView: UIView! {
        didSet {
            searchContainerView.isHidden = true
        }
    }
    private var searchVC: SearchTableVC! {
        didSet {
            searchVC.showsHeader = false
            searchVC.showsSearchBar = false
            searchVC.keyboardDismissMode = .onDrag
        }
    }
    
    private weak var captionCell: LiveTagsCaptionCell!
    
    var didHideOptions:((Bool) -> Void)?
    var didUpdateLiveOptions: ((StoryOptions) -> Void)?
    var viewHeightConstraint: NSLayoutConstraint?
    
    var preferredBgContainColor: UIColor = .clear
    var isHidedOptions: Bool = true
    var isVC: Bool = true
    var enableStreamSchedule = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = isVC ? preferredBackgroundColor : .clear
        
        tableView.estimatedSectionHeaderHeight = .leastNormalMagnitude
        tableView.estimatedSectionFooterHeight = .leastNormalMagnitude
        tableView.register(TagsListCell.nib(), forCellReuseIdentifier: TagsListCell.nameOfClass)
        tableView.register(LiveTagsCaptionCell.nib(), forCellReuseIdentifier: LiveTagsCaptionCell.nameOfClass)
        tableView.register(LiveBroadcastTimeTVC.nib(), forCellReuseIdentifier: LiveBroadcastTimeTVC.nameOfClass)
        tableView.register(ToggleTVC.nib(), forCellReuseIdentifier: ToggleTVC.nameOfClass)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.tableFooterView = UIView()
        
        if !isVC {
            statusBarGapFillerView.isHidden = true
            statusBarGapFillerViewHeightConstraint.constant = 0
        }
        
        if storyOptions.tags.hashTags.isEmpty {
            sectionHeaderHeights[StoryTagSection.hashTags] = 0
            sectionFooterHeights[StoryTagSection.hashTags] = 0
        }
        
        if storyOptions.tags.userTags.isEmpty {
            sectionHeaderHeights[StoryTagSection.userTags] = 0
            sectionFooterHeights[StoryTagSection.userTags] = 0
        }
        
        searchContainerView.topAnchor.constraint(equalTo: view.topAnchor, constant: captionHeight).isActive = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard navigationController?.topViewController == self else { return }

        super.viewWillAppear(animated)
        
        showNavigationBar()
        
        let rightButton = UIBarButtonItem(
            title: "Done",
            style: .plain,
            target: self,
            action: #selector(handleEndStreamingTap)
        )
        rightButton.tintColor = UIColor.Puffy.Green.booger
        navigationItem.rightBarButtonItem = rightButton
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.barStyle = .default
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let searchVC = segue.destination as? SearchTableVC {
            self.searchVC = searchVC
            searchVC.showsHeader = false
        }
    }
   
    // ========
    // MARK: - Tag Handling
    // ========
    
    func addSelectedTag(tag: String, tagType: TagType) {
        setSearchVisibility(enabled: false)
        
        storyOptions.tags.userTags = captionCell.textView.tags.userTags
        updateTagList(section: .userTags)
    }
    
    func setSearchVisibility(enabled: Bool) {
        if enabled {
            //navigationItem.rightBarButtonItem?.title = CaptionEditingState.tagEditing.rightBarButtonTitle
            view.bringSubviewToFront(searchContainerView)
            searchContainerView.isHidden = false
        } else {
            //navigationItem.title = defaultEditingState.navBarTitle(from: storyOptions.contentType)
            //navigationItem.rightBarButtonItem?.title = defaultEditingState.rightBarButtonTitle
            view.sendSubviewToBack(searchContainerView)
            searchContainerView.isHidden = true
        }
    }
    
    private func cancelSearchEntry() {
        setSearchVisibility(enabled: false)
    }
    
    // ========
    // MARK: - Actions
    // ========
    
    @objc private func handleEndStreamingTap() {
        if self.storyOptions.id.isEmpty == false {
            APIClient.updateShowcase(showcaseId: self.storyOptions.id, options: self.storyOptions) { (_) in }
        } else {
            func showMessage(_ message: String, animated: Bool) {
                SwiftSpinner.show(message, animated: animated).addTapHandler ({
                    SwiftSpinner.hide()
                })
            }
            
            guard let asset = self.storyOptions.asset else {
                showMessage("Posting failed: asset nil", animated: false)
                return
            }
            if self.storyOptions.liveSettings["startAt"] == nil {
                self.storyOptions.liveSettings["startAt"] = Date().addingMinutes(30).iso8601()
            }
            APIClient.postShowcase_v1(asset: asset, options: self.storyOptions) { (result) in
                switch result {
                case .success( _):
                    break
                case .failure(let error):
                    showMessage("Posting failed: \(error.localizedDescription)", animated: false)
                }
            }
        }
        navigationController?.popToRootViewController(animated: true)
    }
    
    public var storyOptions: StoryOptions = StoryOptions.createDefaultForLive() {
        didSet {
            didUpdateLiveOptions?(self.storyOptions)
        }
    }
    private enum StoryTagSection: Int, CaseIterable {
        case caption, hideOptions, hashTags, userTags, puffcastTime, privateStream, sendTo, recipients, chatDisabled, trailer, scheduleStream, streamTime
    }
    private enum TagListCells: String {
        case hashTagsListCell, userTagsListCell
    }
    private var sectionHeights: [StoryTagSection: CGFloat] = [
        StoryTagSection.caption : captionHeight,
        StoryTagSection.hideOptions : tagsCellHeight,
        StoryTagSection.hashTags : tagsCellHeight,
        StoryTagSection.userTags : tagsCellHeight,
        StoryTagSection.puffcastTime: captionHeight,
        StoryTagSection.privateStream: tagsCellHeight,
        StoryTagSection.sendTo : UITableView.automaticDimension,
        StoryTagSection.recipients : tagsCellHeight,
        StoryTagSection.chatDisabled: tagsCellHeight,
        StoryTagSection.trailer: 0,
        StoryTagSection.scheduleStream: tagsCellHeight,
        StoryTagSection.streamTime: tagsCellHeight
    ]
    private var sectionHeaderHeights: [StoryTagSection: CGFloat] = [
        StoryTagSection.caption : 0,
        StoryTagSection.hideOptions : 0,
        StoryTagSection.hashTags : UITableView.automaticDimension,
        StoryTagSection.userTags : UITableView.automaticDimension,
        StoryTagSection.puffcastTime: 0,
        StoryTagSection.privateStream: 0,
        StoryTagSection.sendTo : UITableView.automaticDimension,
        StoryTagSection.recipients : 0,
        StoryTagSection.chatDisabled: 0,
        StoryTagSection.trailer: 0,
        StoryTagSection.scheduleStream: 0,
        StoryTagSection.streamTime: 0
    ]
    private var sectionFooterHeights: [StoryTagSection: CGFloat] = [
        StoryTagSection.caption : UITableView.automaticDimension,
        StoryTagSection.hideOptions : 0,
        StoryTagSection.hashTags : UITableView.automaticDimension,
        StoryTagSection.userTags : 0,
        StoryTagSection.puffcastTime: 0,
        StoryTagSection.privateStream: 0,
        StoryTagSection.sendTo : 0,
        StoryTagSection.recipients : 0,
        StoryTagSection.chatDisabled: 0,
        StoryTagSection.trailer: 0,
        StoryTagSection.scheduleStream: 0,
        StoryTagSection.streamTime: 0
    ]
    
    // ========
    // MARK: - Cell Updating
    // ========
    
    private func updateSendToCell() {
        sectionFooterHeights[.sendTo] = storyOptions.tags.recipients.isEmpty ? UITableView.automaticDimension : 0
        let indexPaths = [IndexPath(row: 0, section: StoryTagSection.sendTo.rawValue)]
        tableView.reloadRows(at: indexPaths, with: .automatic)
    }
}

extension CreateLiveInfoVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return isHidedOptions ? 4 : StoryTagSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = StoryTagSection(rawValue: indexPath.section)!
        switch section {
        case .caption:
            let cell = tableView.dequeueReusableCell(withIdentifier: LiveTagsCaptionCell.nameOfClass, for: indexPath) as! LiveTagsCaptionCell
            cell.preferredColor = .white
            cell.setup(storyOptions: storyOptions)
            cell.textView.taggingDelegate = self
            cell.textView.forwardedDelegate = self
            cell.didChangeCoverPhoto = { [weak self] image in
                guard let self = self else { return }
                self.storyOptions.image = image
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            captionCell = cell
            searchVC.didSelectSearchItem = cell.textView.addSearchItemAsTag(searchItem:)
            return cell
        case .hashTags:
            let cell = tableView.dequeueReusableCell(withIdentifier: TagsListCell.nameOfClass, for: indexPath) as! TagsListCell
            cell.tagsListView.setup(tags: storyOptions.tags.hashTags, shouldAllowDeletion: true, includeTagSymbols: true)
            cell.tagsListView.didPressDeleteTag = { [weak self](_, tag) in
                guard let self = self else { return }
                guard let entryTag = tag as? EntryTag else { return }
                
                self.captionCell.textView.removeTag(tag: entryTag)
                if self.storyOptions.tags.hashTags.isEmpty {
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            return cell
        case .userTags:
            let cell = tableView.dequeueReusableCell(withIdentifier: TagsListCell.nameOfClass, for: indexPath) as! TagsListCell
            cell.tagsListView.setup(tags: storyOptions.tags.userTags, shouldAllowDeletion: true, includeTagSymbols: true)
            cell.tagsListView.didPressDeleteTag = { [weak self](_, tag) in
                guard let self = self else { return }
                guard let entryTag = tag as? EntryTag else { return }

                self.captionCell.textView.removeTag(tag: entryTag)
                if self.storyOptions.tags.userTags.isEmpty {
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            return cell
        case .privateStream:
            let cell = tableView.dequeueReusableCell(withIdentifier: ToggleTVC.nameOfClass, for: indexPath) as! ToggleTVC
            cell.titleLabel.text = storyOptions.showcaseType == .live ? "Private Stream" : "Private Puffcast"
            cell.toggleView.isOn = self.storyOptions.isPrivate
            cell.didChangeToggle = { [weak self] isOn in
                guard let self = self else { return }
                self.storyOptions.isPrivate = isOn
                if isOn == false {
                    self.storyOptions.tags.recipients.removeAll()
                }
                self.tableView.reloadData()
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            return cell
        case .sendTo:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
            let numRecipients = storyOptions.tags.recipients.count
            cell.textLabel?.textColor = UIColor.Puffy.Theme.Grayscale.inverted
            cell.accessoryType = storyOptions.isPrivate ? .disclosureIndicator : .none
            cell.textLabel?.text = "No one"
            if numRecipients > 0 {
                guard let firstPersonName = storyOptions.tags.recipients.first?.username else { return cell }
                if numRecipients > 1 {
                    cell.textLabel?.text = "\(firstPersonName) and \(numRecipients - 1) more"
                } else {
                    cell.textLabel?.text = firstPersonName
                }
            }
            return cell
        case .recipients:
            let cell = tableView.dequeueReusableCell(withIdentifier: TagsListCell.nameOfClass, for: indexPath) as! TagsListCell
            let recipients = storyOptions.tags.recipientsAsTags
            cell.tagsListView.setup(tags: recipients, shouldAllowDeletion: true, includeTagSymbols: true)
            cell.tagsListView.didPressDeleteTag = { [weak self] (index, tag) in
                guard let self = self else { return }
                guard tag is EntryTag else { return }

                self.storyOptions.tags.recipients.remove(at: index)
                if self.storyOptions.tags.recipients.isEmpty {
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            return cell
        case .hideOptions:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
            cell.textLabel?.text = isHidedOptions ? "show options" : "hide options"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.font = UIFont(style: .black, size: 15)
            cell.textLabel?.textColor = UIColor.Puffy.Theme.Grayscale.inverted
            return cell
        case .chatDisabled:
            let cell = tableView.dequeueReusableCell(withIdentifier: ToggleTVC.nameOfClass, for: indexPath) as! ToggleTVC
            cell.toggleView.isOn = self.storyOptions.liveSettings["chatsDisabled"] as? Bool ?? false
            cell.titleLabel.text = "Chats Disabled"
            cell.didChangeToggle = { [weak self] isOn in
                guard let self = self else { return }
                self.storyOptions.liveSettings["chatsDisabled"] = isOn
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            return cell
        case .puffcastTime:
            let cell = tableView.dequeueReusableCell(withIdentifier: LiveBroadcastTimeTVC.nameOfClass, for: indexPath) as! LiveBroadcastTimeTVC
            if self.storyOptions.id.isEmpty == false {
                cell.minStartTimeIn = 5
            }
            cell.didSetBroadcastTime = { [weak self] selectedDate in
                guard let self = self else { return }
                self.storyOptions.liveSettings["startAt"] = selectedDate?.iso8601()
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            return cell
        case .trailer:
            let cell = tableView.dequeueReusableCell(withIdentifier: ToggleTVC.nameOfClass, for: indexPath) as! ToggleTVC
            cell.titleLabel.text = "Add Trailer"
            return cell
        case .scheduleStream:
            let cell = tableView.dequeueReusableCell(withIdentifier: ToggleTVC.nameOfClass, for: indexPath) as! ToggleTVC
            cell.titleLabel.text = "Schedule Stream"
            cell.toggleView.isOn = self.enableStreamSchedule
            cell.didChangeToggle = { [weak self] isOn in
                guard let self = self else { return }
                self.enableStreamSchedule = isOn
                if isOn == false {
                    self.storyOptions.liveSettings["startAt"] = nil
                    self.didUpdateLiveOptions?(self.storyOptions)
                }
                self.tableView.reloadData()
            }
            return cell
        case .streamTime:
            let cell = tableView.dequeueReusableCell(withIdentifier: LiveBroadcastTimeTVC.nameOfClass, for: indexPath) as! LiveBroadcastTimeTVC
            cell.minStartTimeIn = 5
            cell.titleLabel.text = ""
            if self.storyOptions.liveSettings["startAt"] == nil {
                cell.dateTimeTF.text = ""
            }
            cell.didSetBroadcastTime = { [weak self] selectedDate in
                guard let self = self else { return }
                self.storyOptions.liveSettings["startAt"] = selectedDate?.iso8601()
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let section = StoryTagSection(rawValue: indexPath.section)!
        if section == .sendTo {
            cell.backgroundColor = preferredBgContainColor
        } else {
            cell.backgroundColor = preferredBgContainColor
        }
        cell.selectionStyle = .none
    }
}

extension CreateLiveInfoVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = StoryTagSection(rawValue: indexPath.section)!
        let isShowed: Bool
        switch section {
        case .sendTo:
            isShowed = storyOptions.isPrivate
        case .hashTags:
            isShowed = storyOptions.tags.hashTags.count > 0
        case .userTags:
            isShowed = storyOptions.tags.userTags.count > 0
        case .recipients:
            isShowed = (storyOptions.isPrivate && storyOptions.tags.recipientsAsTags.count > 0)
        case .puffcastTime:
            isShowed = (storyOptions.showcaseType == .puffcast)
        case .trailer:
            isShowed = (storyOptions.showcaseType == .puffcast)
        case .scheduleStream:
            isShowed = (storyOptions.showcaseType == .live)
        case .streamTime:
            isShowed = (storyOptions.showcaseType == .live) && (enableStreamSchedule)
        default:
            isShowed = true
        }
        return isShowed ? sectionHeights[section]! : 0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = StoryTagSection(rawValue: section)!
        switch section {
        case .sendTo:
            return storyOptions.isPrivate ? sectionHeaderHeights[section]! : 0
        default:
            return sectionHeaderHeights[section]!
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let section = StoryTagSection(rawValue: section)!
        return sectionFooterHeights[section]!
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = StoryTagSection(rawValue: section)!
        let labelText: String
        switch section {
        case .hashTags:
            labelText = "Your Hashtags"
        case .userTags:
            labelText = "Your Mentioned People"
        case .sendTo:
            labelText = "Invite people to your private stream"
        default:
            return nil
        }
        
        let label = UILabel()
        label.font = UIFont(style: .black, size: 18)
        label.textColor = UIColor.Puffy.Theme.Grayscale.inverted
        label.text = labelText
        label.adjustsFontSizeToFitWidth = true
        
        // Place the label in a view to provide padding for the label.
        let view = UIView()
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: view.topAnchor, constant: 5).isActive = true
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5).isActive = true
        label.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12).isActive = true
        label.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12).isActive = true
        view.backgroundColor = preferredBgContainColor
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont(style: .regular, size: 14)
        label.textColor = UIColor.Puffy.Theme.Grayscale.tg7
        let section = StoryTagSection(rawValue: section)!
        switch section {
        case .caption:
            label.text = "Use # to hashtag your content and @ to mention a person."
        case .hashTags:
            if storyOptions.tags.hashTags.count > 0 {
                label.text = "users will not receive notifications on edited hashtags"
            }
        default:
            return nil
        }
        
        // Place the label in a view to provide padding for the label.
        let view = UIView()
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        label.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12).isActive = true
        label.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12).isActive = true
        view.backgroundColor = preferredBgContainColor
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = StoryTagSection(rawValue: indexPath.section)!
        switch section {
        case .hideOptions:
            self.isHidedOptions = !self.isHidedOptions
            self.tableView.reloadData()
            didHideOptions?(self.isHidedOptions)
        case .sendTo:
            let listStoryRecipientsTableVC = UIStoryboard(name: UIStoryboard.Name.createStory, bundle: nil).instantiateViewController(withIdentifier: ListStoryRecipientsTableVC.nameOfClass) as! ListStoryRecipientsTableVC
            listStoryRecipientsTableVC.setup(options: storyOptions)
            listStoryRecipientsTableVC.didChangeStoryOptions = { [weak self] (newStoryOptions) in
                guard let self = self else { return }
                self.storyOptions = newStoryOptions
                self.updateTagList(section: .recipients)
                self.updateSendToCell()
                self.didUpdateLiveOptions?(self.storyOptions)
            }
            navigationController?.pushViewController(listStoryRecipientsTableVC, animated: true)
        default:
            return
        }
    }
}

// ========
// MARK: - StoryTagsVC: PuffyTextViewDelegate
// ========
extension CreateLiveInfoVC: UITextViewDelegate {
    private func updateTagList(section: StoryTagSection) {
        let indexPath = IndexPath(row: 0, section: section.rawValue)
        
        var tags: [EntryTag]
        switch section {
        case .hashTags:
            tags = storyOptions.tags.hashTags
        case .userTags:
            tags = storyOptions.tags.userTags
        case .recipients:
            tags = storyOptions.tags.recipientsAsTags
        default:
            return
        }
        
        if tags.isEmpty {
            sectionHeaderHeights[section] = 0
            sectionHeights[section] = 0
        } else {
            sectionHeaderHeights[section] = (section != .recipients) ? UITableView.automaticDimension : 0
            sectionHeights[section] = tagsCellHeight
        }
        
        // Refresh the height of the table
        tableView.beginUpdates()
        tableView.endUpdates()
        
        // Update the list of tags associated with this section
        let tagsListCell = tableView.cellForRow(at: indexPath) as! TagsListCell
        tagsListCell.tagsListView.update(tags: tags)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        storyOptions.caption = textView.text
        storyOptions.rawDescription = captionCell.textView.getMarkedUpText()
        didUpdateLiveOptions?(self.storyOptions)
    }
}

// ========
// MARK: - StoryTagsVC: TagTextViewDelegate
// ========
extension CreateLiveInfoVC: TagTextViewDelegate {
    func tagsDidUpdate(tags: [EntryTag]) {
        if storyOptions.tags.userTags != captionCell.textView.tags.userTags {
            storyOptions.tags.userTags = captionCell.textView.tags.userTags
            updateTagList(section: .userTags)
        }
        if storyOptions.tags.hashTags != captionCell.textView.tags.hashTags {
            storyOptions.tags.hashTags = captionCell.textView.tags.hashTags
            updateTagList(section: .hashTags)
        }
        didUpdateLiveOptions?(self.storyOptions)
    }
    
    func didBeginEnteringTag(tagType: SearchTab) {
        setSearchVisibility(enabled: true)
        searchVC.searchBarWithcancel.searchBar!.text = nil
        searchVC.filterContent(for: "", tagType: (tagType == .hashtags) ? .hashtags : .people)
    }
    
    func didEndEnteringTag() {
        setSearchVisibility(enabled: false)
    }
    
    func didChangeTagSearch(tag: String, tagType: TagType) {
        searchVC.searchBarWithcancel.searchBar!.text = tag
        searchVC.filterContent(for: tag, tagType: (tagType == .hash) ? .hashtags : .people)
    }
    
//    func didBeginEnteringTag(tagType: TagType) {
//        setSearchVisibility(enabled: true)
//        searchVC.searchBarWithcancel.searchBar!.text = nil
//        searchVC.filterContent(for: "", tagType: (tagType == .hashTag) ? .hashtags : .people)
//    }
//
//    func didEndEnteringTag() {
//        setSearchVisibility(enabled: false)
//    }
//
//    func tagsDidUpdate(tags: [EntryTag]) {
//        if storyOptions.userTags != captionCell.textView.tags.userTags {
//            storyOptions.userTags = captionCell.textView.tags.userTags
//            updateTagList(section: .userTags)
//        }
//        if storyOptions.hashTags != captionCell.textView.tags.hashTags {
//            storyOptions.hashTags = captionCell.textView.tags.hashTags
//            updateTagList(section: .hashTags)
//        }
//        didUpdateLiveOptions?(self.storyOptions)
//    }
//
//    func didChangeTagSearch(tag: String, tagType: TagType) {
//        searchVC.searchBarWithcancel.searchBar!.text = tag
//        searchVC.filterContent(for: tag, tagType: (tagType == .hashTag) ? .hashtags : .people)
//    }
}
