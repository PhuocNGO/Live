//
//  PhenixPublisher.swift
//  PuffyApp
//
//  Created by Apple2 Li on 10/9/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import Foundation
import PhenixSdk

protocol PhenixPublisherDelegate: class {
    func dataQualityChangedCallback(publisher: PhenixExpressPublisher?,
                                    status: PhenixDataQualityStatus,
                                    reason: PhenixDataQualityReason)
    func didStartRender(renderer: PhenixRenderer?)
    func didReceivedFrame(frame: CMSampleBuffer?, isVideo: Bool)
}

struct PhenixPublishResponse {
    let streamId: String?
}

struct PhenixChannelExpressShareConfiguration {

    let channelExpress: PhenixChannelExpress
    let roomExpress: PhenixRoomExpress

    init(backendEndpointUri: String) {
        let pcastExpressOptions = PhenixPCastExpressFactory.createPCastExpressOptionsBuilder()
            .withBackendUri(backendEndpointUri)
            .buildPCastExpressOptions()

        let roomExpressOptions = PhenixRoomExpressFactory.createRoomExpressOptionsBuilder()
            .withPCastExpressOptions(pcastExpressOptions)
            .buildRoomExpressOptions()

        let channelExpressOptions = PhenixChannelExpressFactory.createChannelExpressOptionsBuilder()
            .withRoomExpressOptions(roomExpressOptions)
            .buildChannelExpressOptions()

        self.channelExpress = PhenixChannelExpressFactory.createChannelExpress(channelExpressOptions)!
        self.roomExpress = PhenixRoomExpressFactory.createRoomExpress(roomExpressOptions)
    }
}
