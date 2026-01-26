import Foundation

struct SportsChannel: Codable, Identifiable {
    let id = UUID()
    let name: String
    let channel_name: String?
    let code: String?
    let channel_code: String? // Added to satisfy Codable
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
        return SportsChannel(name: name, channel_name: channel_name, code: code, channel_code: channel_code, url: url, image: image, tournament: tournament, home_team: home_team, away_team: away_team, match_info: match_info, sport_category: sport_category, status: status, start: start, end: end, time: time, country: country, countryIMG: countryIMG, gameID: gameID)
    }
    
    // Custom Decoding Init
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id is initialized by default value
        name = try container.decode(String.self, forKey: .name)
        channel_name = try container.decodeIfPresent(String.self, forKey: .channel_name)
        url = try container.decode(String.self, forKey: .url)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        tournament = try container.decodeIfPresent(String.self, forKey: .tournament)
        home_team = try container.decodeIfPresent(String.self, forKey: .home_team)
        away_team = try container.decodeIfPresent(String.self, forKey: .away_team)
        match_info = try container.decodeIfPresent(String.self, forKey: .match_info)
        sport_category = try container.decodeIfPresent(String.self, forKey: .sport_category)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        start = try container.decodeIfPresent(String.self, forKey: .start)
        end = try container.decodeIfPresent(String.self, forKey: .end)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        countryIMG = try container.decodeIfPresent(String.self, forKey: .countryIMG)
        gameID = try container.decodeIfPresent(String.self, forKey: .gameID)
        
        // Decode channel_code
        let cCode = try container.decodeIfPresent(String.self, forKey: .channel_code)
        channel_code = cCode
        
        // Logic: code ?? channel_code
        if let c = try container.decodeIfPresent(String.self, forKey: .code) {
            code = c
        } else {
            code = cCode
        }
    }
    
    // Memberwise Init
    init(name: String, channel_name: String? = nil, code: String? = nil, channel_code: String? = nil, url: String, image: String? = nil, tournament: String? = nil, home_team: String? = nil, away_team: String? = nil, match_info: String? = nil, sport_category: String? = nil, status: String? = nil, start: String? = nil, end: String? = nil, time: String? = nil, country: String? = nil, countryIMG: String? = nil, gameID: String? = nil) {
        self.name = name
        self.channel_name = channel_name
        self.code = code
        self.channel_code = channel_code
        self.url = url
        self.image = image
        self.tournament = tournament
        self.home_team = home_team
        self.away_team = away_team
        self.match_info = match_info
        self.sport_category = sport_category
        self.status = status
        self.start = start
        self.end = end
        self.time = time
        self.country = country
        self.countryIMG = countryIMG
        self.gameID = gameID
    }
    
    enum CodingKeys: String, CodingKey {
        case name, channel_name, code, channel_code, url, image, tournament, home_team, away_team, match_info, sport_category, status, start, end, time, country, countryIMG, gameID
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
