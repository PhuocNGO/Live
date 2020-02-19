//
//  PhenixLiveDelegate.swift
//  PuffyApp
//
//  Created by Apple2 on 11/10/18.
//  Copyright © 2018 Puffy. All rights reserved.
//

import Foundation
import UIKit

public protocol PhenixLiveOverlayDelegate: class {
    
    var didSendMessage: ((String)->Void)?  { get set }
    var didSendSticker: ((Int,Int)->Void)? { get set }
    var didSendCommand: ((PhenixMessageData.CommandType)->Void)?  { get set }
    var didPressEnd: (()->Void)? { get set }
    var didSwitchCamera: (()->Void)? { get set }
    var didPressCamera: (()->Void)? { get set }
    var didPressFlash: (()->Void)? { get set }
    var didPressViewer: (()->Void)? { get set }
    var didPressMicro: (()->Void)? { get set }
    var didChangeBgColor: ((UIColor)->Void)? { get set }
    var didOpenMenu: ((String, String)->Void)? { get set }
    var didPressStart: (()->Void)? {get set}
    
    func initMessage(_ messages: [PhenixMessageData])
    func addMessage(_ message: PhenixMessageData )
    func sendLike(fromHost: Bool)
    func sendSticker(data: PhenixMessageData)
    func updateForChatU(isCameraOn: Bool)
    func updateForAudienceUI()
    func updateViewersNumber(numb: Int)
    func setViewersNumber(numb: Int)
    func updateCameraButton(isOn: Bool)
    func updateTimeLabel(seconds: Int)
    func updateChatStatus(isDisabled: Bool)
    func updateMicroStatus(isMuted: Bool)
    func updateFlashStatus(isFlashOn: Bool)
    func enableStartButton(isOn: Bool)
}
