import Foundation
import Combine

class AppViewModel: ObservableObject {
    @Published var channels: [SportsChannel] = []
    
    // Raw Events
    private var allEvents: [SportsChannel] = []
    
    // Processed Events strings
    @Published var liveEvents: [GroupedEvent] = []
    @Published var upcomingEvents: [GroupedEvent] = []
    
    // EPG Data
    private var epgData: [String: EPGChannelData] = [:]
    private var epgMap: [String: String] = [:] // Normalized Name -> EPG Key
    
    @Published var isLoading = false
    @Published var searchText: String = ""
    
    // Channels Filtering
    @Published var channelSearchText: String = ""
    @Published var selectedCountry: String? = nil
    
    // Events Filtering
    @Published var selectedCategory: String = "All"
    
    var availableCategories: [String] {
        let categories = allEvents.compactMap { $0.sport_category }.filter { !$0.isEmpty }
        var unique = Array(Set(categories)).sorted()
        
        // Ensure standard order: All, Soccer, then others
        if unique.contains("Soccer") {
            unique.removeAll { $0 == "Soccer" }
            unique.insert("Soccer", at: 0)
        }
        unique.insert("All", at: 0)
        return unique
    }
    
    // Derived Channels
    var filteredChannels: [SportsChannel] {
        var res = channels
        
        // Country Filter
        if let country = selectedCountry {
            res = res.filter { $0.country == country }
        }
        
        // Search Filter
        if !channelSearchText.isEmpty {
            res = res.filter { $0.name.localizedCaseInsensitiveContains(channelSearchText) }
        }
        
        return res
    }
    
    var availableCountries: [String] {
        let countries = channels.compactMap { $0.country }.filter { !$0.isEmpty }
        return Array(Set(countries)).sorted()
    }
    
    private let network = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce search
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterAndGroupEvents()
            }
            .store(in: &cancellables)
            
        // Listen to category changes
        $selectedCategory
            .sink { [weak self] _ in
                // Need to dispatch async to avoid update cycles or simply call
                DispatchQueue.main.async {
                    self?.filterAndGroupEvents()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        self.isLoading = true
        let group = DispatchGroup()
        
        group.enter()
        network.fetchChannels { [weak self] items in
            self?.channels = items
            group.leave()
        }
        
        group.enter()
        network.fetchEvents { [weak self] items in
            self?.allEvents = items
            group.leave()
        }
        
        group.enter()
        network.fetchEPG { [weak self] res in
            if let data = res?.data {
                self?.processEPG(data)
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            // Hydrate events with channel status AFTER both are loaded
            self.filterAndGroupEvents()
            self.isLoading = false
        }
    }
    
    private func filterAndGroupEvents() {
        // 1. Filter by Search
        var filtered = searchText.isEmpty ? allEvents : allEvents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.league ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.home_team ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.away_team ?? "").localizedCaseInsensitiveContains(searchText)
        }
        
        // 2. Filter by Category
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.sport_category == selectedCategory }
        }
        
        // 3. Grouping & Hydration
        var groups: [String: GroupedEvent] = [:]
        
        // Create a lookup map for global channels for faster status access
        // Map Name -> Status, Code -> Status (Normalized: Lowercase + Trimmed)
        var statusMap: [String: String] = [:]
        
        func normalize(_ s: String?) -> String? {
            return s?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        
        for c in self.channels {
            if let s = c.status {
                if let name = normalize(c.name) { statusMap[name] = s }
                if let code = normalize(c.code) { statusMap[code] = s }
                // Also map channel_name if different
                if let cname = normalize(c.channel_name), cname != normalize(c.name) {
                    statusMap[cname] = s
                }
            }
        }
        
        for item in filtered {
            let key = item.gameID ?? item.match_info ?? item.name
            
            // HYDRATION: Check if this item (channel) has status. If not (or if offline), lookup global status.
            var channelItem = item
            if channelItem.status == nil || channelItem.status?.lowercased() == "offline" {
                var foundStatus: String? = nil
                
                // 1. Try Code
                if let code = normalize(channelItem.code), let s = statusMap[code] {
                    foundStatus = s
                }
                // 2. Try Name
                else if let name = normalize(channelItem.name), let s = statusMap[name] {
                    foundStatus = s
                }
                // 3. Try Channel Name
                else if let cname = normalize(channelItem.channel_name), let s = statusMap[cname] {
                    foundStatus = s
                }
                
                if let s = foundStatus {
                    channelItem = channelItem.with(status: s)
                }
            }
            
            if groups[key] == nil {
                groups[key] = GroupedEvent(id: key, displayItem: item, channels: [])
            }
            groups[key]?.channels.append(channelItem)
        }
        
        // Filter out events without any channels
        let allGroups = Array(groups.values).filter { !$0.channels.isEmpty }
        
        // 4. Separation (Live vs Upcoming) & Sorting
        
        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        utcFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // Live
        self.liveEvents = allGroups
            .filter { group in
                guard group.displayItem.status == "live" else { return false }
                
                // Check if event has ended using 'end' field
                if let endStr = group.displayItem.end,
                   let endDate = utcFormatter.date(from: endStr) {
                    // Hide immediately if current time is past end time
                    if Date() > endDate {
                        return false
                    }
                }
                
                return true
            }
            .sorted { ($0.displayItem.start ?? "") < ($1.displayItem.start ?? "") }
            
        // Upcoming (Filter past events)
        self.upcomingEvents = allGroups
            .filter { group in
                guard group.displayItem.status != "live" else { return false }
                
                // Only show events that haven't started yet
                if let startStr = group.displayItem.start,
                   let startDate = utcFormatter.date(from: startStr) {
                    if Date() > startDate { return false }
                }
                
                return true
            }
            .sorted { ($0.displayItem.start ?? "") < ($1.displayItem.start ?? "") }
    }

    
    // --- EPG Helpers ---
    
    private func normalizeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        return name.lowercased()
            .components(separatedBy: allowed.inverted).joined()
            .replacingOccurrences(of: "hd", with: "")
            .replacingOccurrences(of: "fhd", with: "")
            .replacingOccurrences(of: "tv", with: "")
    }
    
    private func processEPG(_ data: [String: EPGChannelData]) {
        self.epgData = data
        self.epgMap.removeAll()
        
        for (key, value) in data {
            // Map Key
            epgMap[normalizeName(key)] = key
            // Map Name
            if let name = value.name {
                epgMap[normalizeName(name)] = key
            }
        }
    }
    
    func getCurrentProgram(for channelName: String) -> EPGProgram? {
        let norm = normalizeName(channelName)
        guard let key = epgMap[norm], let channelData = epgData[key], let programs = channelData.epg_data else {
            return nil
        }
        
        let now = Date()
        let formatter = ISO8601DateFormatter()
        // Improve formatter options if needed, but standard ISO8601 usually works
        
        return programs.first { p in
            // Try standard ISO Parsing
            // Note: API returns "2026-01-24T19:00:00+00:00" which standard ISO8601 parser handles
            if let start = formatter.date(from: p.start),
               let stop = formatter.date(from: p.stop) {
                return now >= start && now < stop
            }
            return false
        }
    }
    
    func formatTime(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: isoString) {
            let local = DateFormatter()
            local.dateFormat = "HH:mm"
            return local.string(from: date)
        }
        return ""
    }
}

// Add league convenience
extension SportsChannel {
    var league: String? {
        return self.tournament ?? self.sport_category
    }
}
