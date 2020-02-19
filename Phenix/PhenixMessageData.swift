//
//  PhenixMessageData.swift
//  PuffyApp
//
//

import Foundation

public class PhenixMessageData: Codable {
    
    enum CodingKeys: String, CodingKey {
        case userId = "userId"
        case userName = "userName"
        case imageUrl = "imageUrl"
        case message = "message"
        case type = "type"
        case command = "command"
        case sticker = "sticker"
        case isHost = "isHost"
        case timestamp = "timestamp"
    }

    public enum MessageType: Int, Codable {
        case message
        case command
    }
    
    public enum CommandType: Int, Codable {
        case none = 0
        case like
        case join
        case left
        case sticker
        case kick
        case mute
        case unmute
    }
    
    public struct Sticker: Codable {
        var id: Int
        var count: Int
        init( id: Int, count: Int ) {
            self.id = id
            self.count = count
        }
    }
    
    var type: MessageType
    var userId: String
    var userName: String
    var imageUrl: URL?
    var message: String
    var command: CommandType
    var timestamp: Date?
    var sticker: Sticker?
    var isHost: Bool
    
    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        userId = try values.decode(String.self, forKey: .userId)
        userName = try values.decode(String.self, forKey: .userName)
        let url = try values.decode(String.self, forKey: .imageUrl)
        imageUrl = URL( string: url)
        message = try values.decode(String.self, forKey: .message)
        var value = try values.decodeIfPresent(Int.self, forKey: .type) ?? MessageType.message.rawValue
        type = MessageType.init(rawValue: value) ?? .message
        value = try values.decodeIfPresent(Int.self, forKey: .command) ?? CommandType.none.rawValue
        command = CommandType.init(rawValue: value) ?? .none
        sticker = try values.decodeIfPresent(Sticker.self, forKey: .sticker)
        isHost = try values.decodeIfPresent(Bool.self, forKey: .isHost) ?? false
        timestamp = try values.decodeIfPresent(Date.self, forKey: .timestamp)
    }
    
    init() {
        type = .message
        command = .none
        userId = ""
        userName = ""
        imageUrl = nil
        message = ""
        sticker = nil
        isHost = false
    }
    
    static func decode( jsonText: String ) -> PhenixMessageData? {
        if let data = jsonText.data(using: .utf8) {
            let decoder = JSONDecoder()
            let decodedData = try? decoder.decode(PhenixMessageData.self, from: data)
            return decodedData
        }
        return nil
    }
    
    public func jsonData() -> String? {
        var json: String? = nil
        let jsonEncoder = JSONEncoder()
        if let data = try? jsonEncoder.encode(self) {
            json = String(data:data, encoding: .utf8)
        }
        return json
    }
    
    
}
