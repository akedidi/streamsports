import Foundation

struct SportsChannel: Codable, Identifiable {
    let id = UUID()
    let name: String
    let channel_name: String?
    let code: String?
    let url: String
    let image: String?
    let tournament: String?
    let home_team: String?
    let away_team: String?
    let match_info: String?
    let sport_category: String?
    let status: String?
    let start: String?
    let time: String?
    let country: String?
    let countryIMG: String?
    let gameID: String?
    
    func with(status: String) -> SportsChannel {
        return SportsChannel(name: name, channel_name: channel_name, code: code, url: url, image: image, tournament: tournament, home_team: home_team, away_team: away_team, match_info: match_info, sport_category: sport_category, status: status, start: start, time: time, country: country, countryIMG: countryIMG, gameID: gameID)
    }
    
    enum CodingKeys: String, CodingKey {
        case name, channel_name, code, url, image, tournament, home_team, away_team, match_info, sport_category, status, start, time, country, countryIMG, gameID
    }
}

// Wrapper for API responses
struct ChannelResponse: Codable {
    let success: Bool?
    let count: Int?
    let channels: [SportsChannel]?
    let events: [SportsChannel]?
}

struct StreamResponse: Codable {
    let success: Bool
    let streamUrl: String?
    let message: String?
}

// UI Model for grouping channels by event
struct GroupedEvent: Identifiable {
    let id: String
    let displayItem: SportsChannel
    var channels: [SportsChannel]
}
