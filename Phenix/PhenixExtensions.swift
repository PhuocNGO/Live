
//
//  PhenixChatMessageExtensions.swift
//  PuffyApp
//
//

import PhenixSdk

extension PhenixChatMessage {

    func messageData( ) -> PhenixMessageData? {
        if let jsonText = self.getObservableMessage()?.getValue() {
            return PhenixMessageData.decode(jsonText: jsonText as String)
        }
        return nil
    }

    func messageTimestamp() -> Date? {
        if let observable: PhenixObservable<NSDate> = self.getObservableTimeStamp() {
            if let timestamp: NSDate = observable.getValue() {
                return timestamp as Date
            }
        }
        return nil
    }
}

extension PhenixRoomChatService {
    @discardableResult func sendMessageData( message: String ) -> PhenixMessageData {
        let data = DefaultsData.phenixMessageData
        data.isHost = PhenixRoomHelper.shared.isHost
        data.message = message
        self.sendMessage(toRoom: data.jsonData())
        return data
    }
    @discardableResult func sendMessageData( command: PhenixMessageData.CommandType, userId: String? = nil ) -> PhenixMessageData {
        let data = DefaultsData.phenixMessageData
        data.isHost = PhenixRoomHelper.shared.isHost
        data.type = .command
        data.command = command
        if let userId = userId {
            data.userId = userId
        }
        self.sendMessage(toRoom: data.jsonData())
        return data
    }
    @discardableResult func sendHostStartedTime( timestamp: Int64 ) -> PhenixMessageData {
        let data = DefaultsData.phenixMessageData
        data.isHost = PhenixRoomHelper.shared.isHost
        data.timestamp = Date(milliseconds: timestamp)
        data.type = .command
        data.command = .none
        self.sendMessage(toRoom: data.jsonData())
        return data
    }
    @discardableResult func sendSticker( id: Int, count: Int ) -> PhenixMessageData {
        let data = DefaultsData.phenixMessageData
        data.isHost = PhenixRoomHelper.shared.isHost
        data.type = .command
        data.command = .sticker
        data.sticker = PhenixMessageData.Sticker( id: id, count: count )
        self.sendMessage(toRoom: data.jsonData())
        return data
    }

}
