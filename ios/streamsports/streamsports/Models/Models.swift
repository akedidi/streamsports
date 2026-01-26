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
    let end: String?
    let time: String?
    let country: String?
    let countryIMG: String?
    let gameID: String?
    
    func with(status: String) -> SportsChannel {
        return SportsChannel(name: name, channel_name: channel_name, code: code, url: url, image: image, tournament: tournament, home_team: home_team, away_team: away_team, match_info: match_info, sport_category: sport_category, status: status, start: start, end: end, time: time, country: country, countryIMG: countryIMG, gameID: gameID)
    }
    
    enum CodingKeys: String, CodingKey {
        case name, channel_name, code, url, image, tournament, home_team, away_team, match_info, sport_category, status, start, end, time, country, countryIMG, gameID
    }
}

extension SportsChannel {
    private static let utcFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
    
    private static let localFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = .current
        return formatter
    }()
    
    var localTime: String {
        guard let start = start else { return time ?? "TBD" }
        
        if let date = Self.utcFormatter.date(from: start) {
            return Self.localFormatter.string(from: date)
        }
        
        return time ?? "TBD"
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
    let rawUrl: String?
    let message: String?
}

// UI Model for grouping channels by event
struct GroupedEvent: Identifiable {
    let id: String
    let displayItem: SportsChannel
    var channels: [SportsChannel]
}

// --- EPG Models ---
struct EPGResponse: Codable {
    let success: Bool
    let data: [String: EPGChannelData]
}

struct EPGChannelData: Codable {
    let name: String?
    let epg_data: [EPGProgram]?
    let logo: String?
}

struct EPGProgram: Codable {
    let title: String
    let description: String?
    let start: String
    let stop: String
}
