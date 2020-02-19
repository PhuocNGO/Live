//
//  PhenixRoomHelper.swift
//  PuffyApp
//
//  Created by Apple2 on 10/15/18.
//  Copyright © 2018 Puffy. All rights reserved.
//


import PhenixSdk
import Nuke

class PhenixRoomHelper {
    
    static let shared: PhenixRoomHelper = PhenixRoomHelper()
    private init() {
    }

    deinit {
        NotificationCenter.default.removeObserver( UIApplication.willTerminateNotification )
        NotificationCenter.default.removeObserver(UIApplication.willResignActiveNotification)
        NotificationCenter.default.removeObserver(UIApplication.didBecomeActiveNotification)
    }

    static public var phenixEndpoint: String {
        return "\(APIRouter.dbUrl)live/"
    }

    public enum BroadcastType: String {
        case showcase = "liveStream"
        case chat = "liveChat"
        case puffcast = "puffcast"
    }
    public var broadcastType: BroadcastType = .showcase

    struct PhenixStatus: OptionSet {
        let rawValue: UInt
        static let none           = PhenixStatus( rawValue: 0 )
        static let hasJoined      = PhenixStatus( rawValue: 1 << 1 )
        static let isViewing      = PhenixStatus( rawValue: 1 << 2 )
        static let isBroadcasting = PhenixStatus( rawValue: 1 << 3 )
        static let isPresenter    = PhenixStatus( rawValue: 1 << 4 )
        static let joinedChat     = PhenixStatus( rawValue: 1 << 5 )
        static let hostOnline     = PhenixStatus( rawValue: 1 << 6 )
        var description : String {
            switch self {
            case .none:          return "none"
            case .hasJoined:     return "hasJoined"
            case .isViewing:     return "isViewing"
            case .isBroadcasting:return "isBroadcasting"
            case .isPresenter:   return "isPresenter"
            case .joinedChat:    return "joinedChat"
            case .hostOnline:    return "hostOnline"
            default:             return "unknown"
            }
        }
    }
    
    enum PhenixNotificationType {
        case status
        case message
        case ended
        case host
        case videoState
        case audioState
        case audienceSize
    }
    
    struct PhenixNotification {
        public var type: PhenixNotificationType? = nil
        public var messages: [PhenixChatMessage]? = nil
        public var status: PhenixRequestStatus? = nil
        public var reason: PhenixStreamEndedReason? = nil
        public var online: Bool = false
        public var state: PhenixTrackState = .disabled
        public var size: Int = 0
        static func status( status: PhenixRequestStatus ) -> PhenixNotification {
            var s = PhenixNotification()
            s.type = .status
            s.status = status
            return s
        }
        static func status( messages: [PhenixChatMessage] ) -> PhenixNotification {
            var s = PhenixNotification()
            s.type = .message
            s.messages = messages
            return s
        }
        static func ended( reason: PhenixStreamEndedReason ) -> PhenixNotification {
            var s = PhenixNotification()
            s.type = .ended
            s.reason = reason
            return s
        }
        static func hostStatus( online: Bool ) -> PhenixNotification {
            var s = PhenixNotification()
            s.type = .host
            s.online = online
            return s
        }
        static func videoState( state: PhenixTrackState ) -> PhenixNotification {
            var s = PhenixNotification()
            s.type = .videoState
            s.state = state
            return s
        }
        static func audioState( state: PhenixTrackState ) -> PhenixNotification {
            var s = PhenixNotification()
            s.type = .audioState
            s.state = state
            return s
        }
        static func audienceSize( size: Int ) -> PhenixNotification {
            var s = PhenixNotification()
            s.type = .audienceSize
            s.size = size
            return s
        }
    }
    
    private var roomOptions: PhenixRoomOptions? {
        get {
            return PhenixRoomServiceFactory.createRoomOptionsBuilder()
                .withName(self.roomAlias)
                .withAlias(self.roomAlias)
                .withType(PhenixRoomType.multiPartyChat)
                .buildRoomOptions()
        }
    }
    private var roomService: PhenixRoomService? = nil
    private var currentSubscriber: PhenixExpressSubscriber? = nil
    private var publisher: PhenixExpressPublisher? = nil
    private var renderer: PhenixRenderer? = nil
    private var pcast: PhenixPCast?
    private var room: PhenixRoom? = nil
    private var userMediaStream: PhenixUserMediaStream? = nil
    private weak var delegate: PhenixPublisherDelegate? = nil
    private var monitorLayer: CALayer? = nil
    
    private var _chatServiceArray:[PhenixRoomChatService] = []
    private var chatService: PhenixRoomChatService? {
        set {
            guard let service = newValue else {
                chatSubscription = nil
                _chatServiceArray.removeAll()
                return
            }
            _chatServiceArray.append( service )
        }
        get {
            return _chatServiceArray.last
        }
    }
    private var _chatSubscriptionArray:[PhenixDisposable] = []
    private var chatSubscription: PhenixDisposable? {
        set {
            guard let subscription = newValue else {
                _chatSubscriptionArray.removeAll()
                return
            }
            _chatSubscriptionArray.append( subscription )
        }
        get {
            return _chatSubscriptionArray.last
        }
    }
    private var membersSubscription: PhenixDisposable? = nil
    private var videoStateSubscription: PhenixDisposable? = nil
    private var audioStateSubscription: PhenixDisposable? = nil
    private var audienceSubscription: PhenixDisposable? = nil
    private var streamSubscription: PhenixDisposable? = nil
    private var joinRoomOptions: PhenixJoinRoomOptions? = nil
    private var roomExpress: PhenixRoomExpress? = nil
    private var mediaConstraints: PhenixUserMediaOptions! {
        get {
            let mediaConstraints = PhenixUserMediaOptions()
            mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.frameRate.rawValue] = [PhenixDeviceConstraint.initWith(30)]
            mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.width.rawValue] = [PhenixDeviceConstraint.initWith(540)]
            mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.height.rawValue] = [PhenixDeviceConstraint.initWith(960)]
            mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.facingMode.rawValue] = [PhenixDeviceConstraint.initWith(self.facingMode)]
            mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.flashMode.rawValue] = [PhenixDeviceConstraint.initWith(self.flashMode)]
            mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.videoSourceRotationMode.rawValue] = [PhenixDeviceConstraint.initWith(PhenixVideoSourceRotationMode.followUiRotation)]
            mediaConstraints.audio.capabilityConstraints[PhenixDeviceCapability.audioEchoCancelationMode.rawValue] = [PhenixDeviceConstraint.initWith(PhenixAudioEchoCancelationMode.on)]
            return mediaConstraints
        }
    }
    private var currentRoomMembers: [PhenixMember] = []
    private var currentPresenter: PhenixMember? = nil
    private var presenterStream: PhenixStream? = nil
    public var facingMode: PhenixFacingMode = .user {
        didSet{
            if facingMode != oldValue {
                self.mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.facingMode.rawValue] = [PhenixDeviceConstraint.initWith(facingMode)]
                self.userMediaStream?.apply(self.mediaConstraints)
            }
        }
    }
    public var flashMode: PhenixFlashMode = .alwaysOff {
        didSet {
            if flashMode != oldValue {
                self.mediaConstraints.video.capabilityConstraints[PhenixDeviceCapability.flashMode.rawValue] = [PhenixDeviceConstraint.initWith(flashMode)]
                self.userMediaStream?.apply(self.mediaConstraints)
            }
        }
    }
    private var timeoutRetry: Int = 0
    private var createRetry: Int = 0
    public var isHost: Bool = false

    public var roomAlias: String = ""
    private var roomId: String? = nil
    private(set) var streamId: String? = nil
    private var screenName: String = ""
    public var placeholderImageUrl: URL? = nil
    private var placeholderImage: UIImage? = nil

    private(set) public var status: PhenixStatus = .none
    private(set) public var isMuted: Bool = false
    private(set) public var isScreenOff: Bool = true
    private(set) public var isBroadcasting: Bool {
        get{ return self.status.contains(.isBroadcasting) }
        set{
            if newValue {
                self.status.formUnion(.isBroadcasting)
            } else {
                self.status.remove(.isBroadcasting)
            }
        }
    }
    private(set) public var isViewing: Bool {
        get{ return self.status.contains(.isViewing) }
        set{
            if newValue {
                self.status.formUnion(.isViewing)
            } else {
                self.status.remove(.isViewing)
            }
        }
    }
    private(set) public var hasJoined: Bool {
        get{ return self.status.contains(.hasJoined) }
        set{
            if newValue {
                self.status.formUnion(.hasJoined)
            } else {
                self.status.remove(.hasJoined)
            }
        }
    }
    private(set) public var isPresenter: Bool {
        get{ return self.status.contains(.isPresenter) }
        set{
            if newValue {
                self.status.formUnion(.isPresenter)
            } else {
                self.status.remove(.isPresenter)
            }
        }
    }
    private(set) public var joinedChat: Bool {
        get{ return self.status.contains(.joinedChat) }
        set{
            if newValue {
                self.status.formUnion(.joinedChat)
            } else {
                self.status.remove(.joinedChat)
            }
        }
    }
    private(set) public var willRetry: Bool = true

    private var CapabilitiesLiveStream: [String] {
        return ["hd","multi-bitrate","real-time","on-demand"]
    }
    private var CapabilitiesHlsSource: [String] {
        return ["hd","multi-bitrate","real-time"] // NOTE: "detected" removed due to SDK update that no longer requires it
    }
    private var CapabilitiesLiveChat: [String] {
        return ["hd","multi-bitrate","real-time"]
    }

    private func stopViewing() {
        guard isViewing == true else { return }
        self.isViewing = false
        self.currentSubscriber = nil
        self.timeoutRetry = 0
        self.willRetry = true
        self.currentPresenter = nil
        self.currentRoomMembers = []
        if self.isBroadcasting == false {
            self.renderer = nil
            self.streamSubscription = nil
            self.streamId = nil
        }
    }

    public func stopBroadcast() {
        guard isBroadcasting == true else { return }
        self.isBroadcasting = false
        self.stopRenderVideo()
        self.stopPublish()
        self.stopUserMedia()
        self.streamSubscription = nil
        self.streamId = nil
    }
    
    private func stopPublish() {
        isBroadcasting = false
        isScreenOff = true
        if self.publisher != nil {
            self.publisher?.stop("ended")
            self.publisher = nil
        }
    }
    
    private func stopUserMedia() {
        if self.userMediaStream != nil {
            self.userMediaStream?.mediaStream.stop()
            self.userMediaStream = nil
        }
    }
    
    public func stopRenderVideo() {
        if self.renderer != nil {
            self.renderer?.stop() //PhenixRenderer
            self.renderer = nil
        }
    }
    
    public func leaveRoom(completion:(() -> Void)? = nil) {
        guard hasJoined == true else {
            completion?()
            return
        }
        self.sendCommand(roomAlias: self.roomAlias, command: .left)
        if isHost && self.broadcastType == .chat {
            APIClient.Users.put(isLiveChatActive: false )
        }
        // remove any detatched stream objects
        self.publisher = nil
        // remove all subscription disposables
        self.audioStateSubscription = nil
        self.audienceSubscription = nil
        self.videoStateSubscription = nil
        self.audienceSubscription = nil
        self.membersSubscription = nil
        self.chatService = nil

        stopViewing()
        stopBroadcast()
        
        self.roomService?.leaveRoom({ [weak self] (service:PhenixRoomService?, status:PhenixRequestStatus) in
            guard let self = self else {
                completion?()
                return
            }
            if self.isHost {
                self._destroyCurrentRoom( completion: completion )
                /*
                service?.destroyRoom({ [weak self] (service:PhenixRoomService?, status:PhenixRequestStatus) in
                    guard let self = self else {
                        completion?()
                        return
                    }
                    self.roomService = nil
                    self.roomExpress = nil
                    self.pcast?.shutdown()
                    self.pcast = nil
                    self.roomAlias = ""
                    self.hasJoined = false
                    completion?()
                })*/
            } else {
                self.roomService = nil
                self.roomExpress = nil
                self.pcast?.shutdown()
                self.pcast = nil
                self.roomAlias = ""
                self.hasJoined = false
                self.status = .none
                completion?()
            }
        })
    }
    
    /**
     This is just an initializer to render the previews
     */
    public func initializeForBroadcast( monitorLayer: CALayer, roomAlias: String? = nil, completion: ((PhenixRendererStartStatus) -> Void)? = nil) {
        self.stopBroadcast()
        if let roomAlias = roomAlias, roomAlias.isEmpty == false {
            self.roomAlias = roomAlias
        } else if self.roomAlias.isEmpty {
            self.roomAlias = DefaultsData.roomAlias ?? ""
        }
        self.screenName = DefaultsData.profileName ?? "Puffy User"
        guard !self.roomAlias.isEmpty else { return }
        self.monitorLayer = monitorLayer

        if let roomExpress = self._createRoomExpress() {
            roomExpress.pcastExpress.getUserMedia(mediaConstraints) { [weak self] (_, userMediaStream) in
                self?.userMediaStream = userMediaStream
                if let renderer = userMediaStream?.mediaStream.createRenderer() {
                    self?.renderer = renderer
                    let status = renderer.start(monitorLayer)
                    completion?(status)
                } else {
                    completion?(.failed)
                }
            }
        } else {
            completion?(.failed)
        }
    }
    
    public func initializeForView( viewLayer: CALayer, roomAlias: String? = nil ) {
        self.stopViewing()
        self.monitorLayer = viewLayer
        self.screenName = DefaultsData.profileName ?? "Puffy User"
    }
    
    public func joinRoom( roomAlias: String? = nil, notificationHandler: ((PhenixNotification) -> Void)? = nil ) {
        NotificationCenter.default.removeObserver( UIApplication.willTerminateNotification )
        NotificationCenter.default.removeObserver(UIApplication.willResignActiveNotification)
        NotificationCenter.default.removeObserver(UIApplication.didBecomeActiveNotification)
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self](notification) in
            self?.leaveRoom()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { (_) in
            //self?._unsubscribeToCurrentStream( reason: PhenixStreamEndedReason.ended, description: "willResignActiveNotification", notificationHandler: notificationHandler )
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self](_) in
            self?._subscribeToStream( notificationHandler: notificationHandler )
        }

        if roomAlias != nil {
            if roomAlias != self.roomAlias {
                leaveRoom()
            }
            self.roomAlias = roomAlias!
        }
        guard !self.roomAlias.isEmpty else { return }
        guard self.hasJoined == false else { return }
        if self.isHost == false {
            self.isHost = (self.roomAlias == DefaultsData.roomAlias)
        }
        self._roomExists() { [weak self] (exists: Bool) in
            if exists {
                self?._joinRoom( notificationHandler: notificationHandler )
            } else {
                self?._createRoom() { [weak self] (created: Bool) in
                    self?._joinRoom( notificationHandler: notificationHandler )
                }
            }
        }
    }
    
    
    public func startBroadcast( asPresenter: Bool = true, notificationHandler: ((PhenixNotification) -> Void)? = nil ) {
        guard isBroadcasting == false else { return }
        guard let userMediaStream = self.userMediaStream else { return }
        self.isBroadcasting = true
        isPresenter = asPresenter
        var capabilities = self.CapabilitiesLiveStream
        if self.broadcastType == .chat {
            capabilities = self.CapabilitiesLiveChat
        } else if self.broadcastType == .puffcast {
            capabilities = self.CapabilitiesHlsSource
        }
        let localPublishOptions = PhenixPCastExpressFactory.createPublishOptionsBuilder()
            .withCapabilities( capabilities )
            .withUserMedia(userMediaStream)
            .buildPublishOptions()
        
        let localPublishToRoomOptions = PhenixRoomExpressFactory.createPublishToRoomOptionsBuilder()
            .withStreamType(PhenixStreamType.user)
            .withMemberRole(asPresenter ? PhenixMemberRole.presenter : PhenixMemberRole.participant)
            .withRoomId(self.roomId)
            .withRoomOptions(roomOptions)
            .withPublishOptions(localPublishOptions)
            .buildPublishToRoomOptions()
        
        self.roomExpress?.publish(toRoom: localPublishToRoomOptions, withCallback: { [weak self] (requestStatus, roomService, publisher) in
            defer {
                notificationHandler?( PhenixNotification.status(status: requestStatus))
            }
            guard requestStatus == PhenixRequestStatus.ok else {
                self?.isBroadcasting = false
                return
            }
            self?.hasJoined = true
            self?.publisher = publisher
            self?.streamId = publisher?.streamId
            self?.isScreenOff = false
            if let streamId = publisher?.streamId, let roomAlias = self?.roomAlias {
                APIClient.postLiveStream(streamId: streamId, roomAlias: roomAlias, roomId: self?.roomId, streamType: self?.broadcastType ?? .chat)
            }
            if let member = roomService?.getSelf() {
                self?.currentRoomMembers.append(member)
            } else {
                if let observable: PhenixObservable<NSArray> = (self?.roomService?.getObservableActiveRoom()?.getValue()?.getObservableMembers()) {
                    if let members: [PhenixMember] = observable.getValue() as? [PhenixMember] {
                        self?.currentRoomMembers = members
                    }
                }
            }
            
        })
    }
    
    public func startRemoteBroadcast( streamUrl: URL, notificationHandler: ((PhenixNotification) -> Void)? = nil ) {
        guard isBroadcasting == false else { return }
        //isPresenter = true
        let remotePublishOptions = PhenixPCastExpressFactory.createPublishRemoteOptionsBuilder()
            .withStreamUri( streamUrl.absoluteString )
            .withCapabilities(self.CapabilitiesHlsSource)
            .withDetachedPublisher()
            .buildPublishRemoteOptions()
        let remotePublishToRoomOptions = PhenixRoomExpressFactory.createPublishToRoomOptionsBuilder()
            .withStreamType(.user)
            .withMemberRole(.presenter)
            .withRoomOptions(roomOptions)
            .withPublishRemoteOptions(remotePublishOptions)
            .buildPublishToRoomOptions()
        self.roomExpress?.publish(toRoom: remotePublishToRoomOptions, withCallback: { [weak self] (requestStatus, roomService, publisher) in
            guard requestStatus == PhenixRequestStatus.ok else {
                //self?.isBroadcasting = false
                notificationHandler?( PhenixNotification.status( status: requestStatus ) )
                return
            }
            self?.hasJoined = true
            //self?.isBroadcasting = true
            //self?.publisher = publisher
            self?.streamId = publisher?.streamId
            //self?.isScreenOff = false
            if let streamId = publisher?.streamId, let roomAlias = self?.roomAlias {
                APIClient.postLiveStream(streamId: streamId, roomAlias: roomAlias, roomId: self?.roomId, streamType: self?.broadcastType ?? .chat)
            }
        })

    }
    
    public func sendMessage( roomAlias: String, message: String ) {
        guard let chatService = self.chatService else { return }
        let data = chatService.sendMessageData(message: message)
        guard let roomId = self.roomId else { return }
        let timestamp = Date().iso8601()
        APIClient.postLiveMessage(roomAlias: roomAlias, roomId: roomId, streamId: self.streamId, streamType: self.broadcastType, timestamp: timestamp, message: data)
    }

    public func sendCommand( roomAlias: String, command: PhenixMessageData.CommandType, userId: String? = nil ) {
        guard let chatService = self.chatService else { return }
        chatService.sendMessageData(command: command, userId: userId)
        //guard let roomId = self.roomId else { return }
        //let timestamp = Date().iso8601()
        //APIClient.postLiveMessage(roomAlias: roomAlias, roomId: roomId, streamId: self.streamId, streamType: self.broadcastType, timestamp: timestamp, message: data)
    }
    
    public func sendSticker( roomAlias: String, id: Int, count: Int ) {
        guard let chatService = self.chatService else { return }
        let data = chatService.sendSticker( id: id, count: count )
        guard let roomId = self.roomId else { return }
        let timestamp = Date().iso8601()
        APIClient.postLiveMessage(roomAlias: roomAlias, roomId: roomId, streamId: self.streamId, streamType: self.broadcastType, timestamp: timestamp, message: data)
    }
    public func sendHostStartedTime(timestamp: Int64) {
        guard let chatService = self.chatService else { return }
        chatService.sendHostStartedTime(timestamp: timestamp)
    }

    /**
     Switch camera button:
     Use the user media stream application and add the media constraint for the facing mode to that instance.
     We use observers at Unlocked to detect the facing mode initially and switch in between
     */
    public func switchCamera( ) {
        facingMode = (facingMode == PhenixFacingMode.user) ? PhenixFacingMode.environment : PhenixFacingMode.user
    }
    
    public func switchFlash() {
        flashMode = (flashMode == .alwaysOff) ? .alwaysOn : .alwaysOff
    }
    
    public func switchAudioState() {
        isMuted = !isMuted
        guard let publisher = self.publisher else { return }
        if isMuted {
            publisher.disableAudio()
        } else {
            publisher.enableAudio()
        }
    }
    
    public func switchVideoState() {
        isScreenOff = !isScreenOff
        guard let publisher = self.publisher else { return }
        if isScreenOff {
            publisher.disableVideo()
        } else {
            publisher.enableVideo()
        }
    }
    
    @discardableResult private func _createRoomExpress() -> PhenixRoomExpress? {
        if self.roomExpress == nil {
            let firebaseIdToken = SessionsManager.shared.firebaseIdToken
            let pcastExpressOptions = PhenixPCastExpressFactory.createPCastExpressOptionsBuilder()
                .withBackendUri(PhenixRoomHelper.phenixEndpoint)
                .addAuthenticationHeader("idtoken",firebaseIdToken)
                .buildPCastExpressOptions()
            let roomExpressOptions = PhenixRoomExpressFactory.createRoomExpressOptionsBuilder()
                .withPCastExpressOptions(pcastExpressOptions)
                .buildRoomExpressOptions()
            
            self.roomExpress = PhenixRoomExpressFactory.createRoomExpress(roomExpressOptions)
            self.pcast = self.roomExpress!.pcastExpress.pcast
        }
        return self.roomExpress
    }
    
    private func _joinChat(notificationHandler: ((PhenixNotification) -> Void)? = nil) {
        //guard self.chatSubscription == nil else { return }
        self.chatService = nil
        guard let _ = self.roomService else { return }
        if self.isHost {
            APIClient.Users.put(isLiveChatActive: true)
        }
        self.chatService = PhenixRoomChatServiceFactory.createRoomChatService(self.roomService)
        self.chatSubscription = self.chatService?.getObservableChatMessages().subscribe { (change: PhenixObservableChange<NSArray>?) in
            if let change = change {
                if let messages = change.value as? [PhenixChatMessage] {
                    if messages.count > 0 {
                        notificationHandler?( PhenixNotification.status(messages: messages) )
                    }
                }
            }
        }
        self.sendCommand(roomAlias: self.roomAlias, command: .join)
    }
    
    private func _subscribeToStream(notificationHandler: ((PhenixNotification) -> Void)? = nil) {
        
        guard isBroadcasting == false else { return }
        
        var presenter: PhenixMember? = nil
        for member in self.currentRoomMembers {
            let role = member.getObservableRole()?.getValue()?.intValue
            if role == PhenixMemberRole.presenter.rawValue {
                presenter = member
            }
        }
        guard presenter != nil else {
            notificationHandler?( PhenixNotification.hostStatus(online: self.isHost) )
            return
        }
        guard presenter?.getSessionId() != self.currentPresenter?.getSessionId() || self.presenterStream == nil else { return }
        guard let stream = presenter?.getObservableStreams().getValue().firstObject as? PhenixStream else { return }

        self.currentPresenter = presenter
        self.currentSubscriber = nil
        self._subscribeToStream(stream: stream, notificationHandler: notificationHandler)
        self.streamSubscription = nil
        self.streamSubscription = self.currentPresenter?.getObservableStreams()?.subscribe({ (change:PhenixObservableChange<NSArray>?) in
            if let change = change {
                let streams = change.value as! [PhenixStream]
                guard let stream = streams.first else {
                    
                    return
                }
                self._subscribeToStream(stream: stream, notificationHandler: notificationHandler)
            }
        })
        
    }
    private func _unsubscribeToCurrentStream( reason: PhenixStreamEndedReason, description: String?, notificationHandler: ((PhenixNotification) -> Void)? = nil ) {
        self.isViewing = false
        self.renderer?.stop()
        self.audienceSubscription = nil
        self.streamSubscription = nil
        self.currentSubscriber = nil
        self.presenterStream = nil
        self.publisher = nil
        self.streamId = nil
        //self.currentPresenter = nil
        logPrint(level: .error, message: "Stream ended: reason: \(reason.rawValue) description: \(description ?? "none")")
        notificationHandler?( PhenixNotification.ended( reason: reason ) )
    }
    private func _subscribeToStream(stream:PhenixStream, notificationHandler: ((PhenixNotification) -> Void)? = nil) {

        let renderLayer = self.monitorLayer
        let monitorOptions = PhenixPCastExpressFactory.createMonitorOptionsBuilder().buildMonitorOptions();
        let rendererOptions = PhenixRendererOptions()
        rendererOptions.aspectRatioMode = PhenixAspectRatioMode.letterbox
        guard let streamUrl = URL( string: stream.getUri() ) else { return }
        guard let streamId = streamUrl.fragment else { return }
        guard self.streamId != streamId else { return }
        self.streamId = streamId
        self.presenterStream = stream
        if self.isBroadcasting == false {
            if let url = URL( string: stream.getUri() ) {
                self.streamId = url.fragment
            }
        }

        let options = PhenixRoomExpressFactory.createSubscribeToMemberStreamOptionsBuilder()
            .withRenderer(renderLayer)
            .withRendererOptions(rendererOptions)
            .withMonitor({ (status: PhenixRequestStatus, retry: PhenixOptionalAction?) in
                // Stream failed to setup, check if retry is a possibility:
                guard status != .ok else {
                    self.isViewing = true
                    notificationHandler?( PhenixNotification.status( status: status ) )
                    return
                }
                self.isViewing = false
                logPrint(level: .error, message: "Stream failed to setup: status: \(status.rawValue)")
                if let retry = retry, retry.isPresent() {
                    if self.roomService != nil {
                        retry.perform()
                    } else {
                        logPrint(level: .error, message: "Stream failed to setup: will not retry")
                        retry.dismiss()
                    }
                } else if status == .timeout {
                    self.isViewing = false
                    if self.timeoutRetry < 3 {
                        self.timeoutRetry = self.timeoutRetry + 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000), execute: { [weak self] in
                            self?._subscribeToStream()
                        })
                    } else {
                        self.willRetry = false
                        self.timeoutRetry = 0
                        notificationHandler?( PhenixNotification.status( status: status ) )
                    }
                }
            }, { [weak self] (reason: PhenixStreamEndedReason, description: String?, retry: PhenixOptionalAction?) in
                // Stream has ended, check if due to failure
                self?._unsubscribeToCurrentStream( reason: reason, description: description, notificationHandler: notificationHandler )
                if let retry = retry, retry.isPresent() {
                    if reason == .failed || reason == .appBackground {
                        retry.perform()
                    } else {
                        retry.dismiss()
                    }
                }
            }, monitorOptions)
            .buildSubscribeToMemberStreamOptions()

        self.roomExpress?.subscribe(toMemberStream: presenterStream, options) { [weak self] (requestStatus: PhenixRequestStatus, subscriber: PhenixExpressSubscriber?, renderer: PhenixRenderer?) in
            guard requestStatus == .ok else {
                logPrint(level: .error, message: "roomExpress.subscribe failed: requestStatus: \(requestStatus.rawValue)")
                self?.isViewing = false
                notificationHandler?( PhenixNotification.status( status: requestStatus ) )
                return
            }
            logPrint(level: .error, message: "roomExpress.subscribe success: roomAlias: \(self?.roomAlias ?? "unknown")")
            self?.renderer = renderer
            self?.timeoutRetry = 0
            self?.currentSubscriber = subscriber
            self?.isViewing = true
            notificationHandler?( PhenixNotification.status( status: requestStatus ) )
        }
    }
    
    private func _setupSubscriptionsToObservers(notificationHandler: ((PhenixNotification) -> Void)? = nil) {
        guard let roomService = self.roomService else { return }
        self.audienceSubscription = roomService.getObservableActiveRoom()?.getValue()?.getObservableEstimatedSize()?.subscribe({ (change:PhenixObservableChange<NSNumber>?) in
            if let change = change {
                notificationHandler?( PhenixNotification.audienceSize(size: change.value.intValue) )
            }
        })

    }
    
    private func _joinRoom( notificationHandler: ((PhenixNotification) -> Void)? = nil ) {
        guard let _ = self._createRoomExpress() else { return }
        guard let roomId = self.roomId else { return }
        if self.isHost {
            APIClient.postLiveStream(streamId: self.streamId, roomAlias: self.roomAlias, roomId: self.roomId, streamType: self.broadcastType )
        }
        self.joinRoomOptions = PhenixRoomExpressFactory.createJoinRoomOptionsBuilder()
            .withScreenName(self.screenName)
            .withRoomAlias(self.roomAlias)
            .withRoomId(roomId)
            .withRole(PhenixMemberRole.audience)
            .buildJoinRoomOptions()
        
        self.roomExpress?.joinRoom(self.joinRoomOptions, { [weak self] (requestStatus: PhenixRequestStatus, roomService: PhenixRoomService?) in
            guard let self = self else { return }
            // Important: Store room service reference, otherwise we will leave channel again immediately:
            self.roomService = roomService
            if requestStatus == .ok {
                // Joined the stream
                self.hasJoined = true
                self.createRetry = 0
                logPrint(level: .info, message: "roomExpress.joinRoom success: roomAlias:\(self.roomAlias)")
                self.room = roomService?.getObservableActiveRoom()?.getValue()
                self._setupSubscriptionsToObservers( notificationHandler: notificationHandler )
                self.membersSubscription = self.room?.getObservableMembers()?.subscribe({ [weak self] (change: PhenixObservableChange<NSArray>?) in
                    let members = change?.value as! [PhenixMember]
                    self?.currentRoomMembers = members
                    self?._joinChat( notificationHandler: notificationHandler )
                    self?._subscribeToStream(notificationHandler:notificationHandler)
                })
            } else if requestStatus == .noStreamPlaying {
                // No stream playing in channel, update UI accordingy
                self.hasJoined = true
                logPrint(level: .info, message: "roomExpress.joinRoom .noStreamPlaying: roomAlias:\(self.roomAlias)")
            } else if requestStatus == .gone {
                if self.createRetry < 3 {
                    self.createRetry = self.createRetry + 1
                    self._createRoom() { [weak self] (created: Bool) in
                        self?._joinRoom( notificationHandler: notificationHandler )
                    }
                } else {
                    logPrint(level: .error, message: "roomExpress.joinRoom .gone - create: failed for roomAlias:\(self.roomAlias)")
                }
            } else {
                // We failed to subscribe and retry attempts must have failed
            }
            notificationHandler?( PhenixNotification.status( status: requestStatus ) )
        })
    }
    
    private func _roomExists( completion: ((Bool) -> Void)? = nil ) {
        guard !self.roomAlias.isEmpty else { return }
        guard let roomExpress = self._createRoomExpress() else { return }
        roomExpress.pcastExpress.wait( forOnline: {
            self.pcast = roomExpress.pcastExpress.pcast
            guard let roomService = PhenixRoomServiceFactory.createRoomService( roomExpress.pcastExpress.pcast ) else { return }
            roomService.getRoomInfo("", self.roomAlias) { (roomService:PhenixRoomService?, status:PhenixRequestStatus, room:PhenixRoom?) in
                self.roomId = room?.getId()
                completion?(status == .ok)
            }
        })
    }
    
    private func _createRoom( completion: ((Bool) -> Void)? = nil ) {
        guard !self.roomAlias.isEmpty else { return }
        guard let roomOptions = self.roomOptions else { return }
        guard let roomExpress = self._createRoomExpress() else { return }
        roomExpress.pcastExpress.wait( forOnline: {
            self.pcast = roomExpress.pcastExpress.pcast
            guard let roomService = PhenixRoomServiceFactory.createRoomService( roomExpress.pcastExpress.pcast ) else { return }
            roomService.createRoom( roomOptions ) { (roomService:PhenixRoomService?, status: PhenixRequestStatus, room: PhenixRoom?) in
                self.roomId = room?.getId()
                completion?(status == .ok)
            }
        })
    }

    private func _destroyCurrentRoom(completion:(() -> Void)? = nil) {
        guard self.hasJoined == true else { return }
        guard let roomId = self.roomId else { return }
        //if let encodedRoomId = roomId.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            let pathParameter = "channel/\(roomId)"
            APIClient.phenixWebApi( method: "DELETE", pathParameter: pathParameter, bodyFields: ["channelId": roomId] ) { [weak self] result in
                guard let self = self else {
                    completion?()
                    return
                }
                self.roomService = nil
                self.roomExpress = nil
                self.pcast?.shutdown()
                self.pcast = nil
                self.roomAlias = ""
                self.hasJoined = false
                self.status = .none
                completion?()
            }
        //}
    }

}
