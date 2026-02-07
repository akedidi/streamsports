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
    
    // Performance Optimization: Cached Status Map
    var channelStatusMap: [String: String] = [:]
    
    // Cached Formatters
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // Adjust logic inside
        return f
    }()
    
    // We use a specific one for standard ISO (no fractional usually)
    private let standardIsoFormatter = ISO8601DateFormatter()
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    
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
        // Start Chromecast Discovery
        _ = ChromecastManager.shared
        
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
    
    func loadData(silent: Bool = false, completion: (() -> Void)? = nil) {
        if !silent { self.isLoading = true }
        let group = DispatchGroup()
        
        group.enter()
        network.fetchChannels { [weak self] items in
            self?.channels = items
            
            // Populate Status Map for O(1) Access
            var map: [String: String] = [:]
            for item in items {
                if let status = item.status {
                    let name = item.name.lowercased()
                    map[name] = status.lowercased()
                }
            }
            self?.channelStatusMap = map
            
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
        
        // Notify on background queue to avoid blocking main thread with processing
        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self = self else { return }
            // Hydrate events with channel status AFTER both are loaded
            self.filterAndGroupEvents {
                DispatchQueue.main.async {
                    if !silent { self.isLoading = false }
                    completion?()
                }
            }
        }
    }
    
    // Async wrapper for Pull to Refresh (Silent load to keep List visible)
    func reload() async {
        return await withCheckedContinuation { continuation in
            loadData(silent: true) {
                continuation.resume()
            }
        }
    }
    
    // Make public and add completion handler for loadData to know when done
    func filterAndGroupEvents(completion: (() -> Void)? = nil) {
        // Capture current state to avoid thread race conditions
        let currentSearch = searchText
        let currentCategory = selectedCategory
        let rawEvents = allEvents
        let rawChannels = channels
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Filter by Search
            var filtered = currentSearch.isEmpty ? rawEvents : rawEvents.filter {
                $0.name.localizedCaseInsensitiveContains(currentSearch) ||
                ($0.league ?? "").localizedCaseInsensitiveContains(currentSearch) ||
                ($0.home_team ?? "").localizedCaseInsensitiveContains(currentSearch) ||
                ($0.away_team ?? "").localizedCaseInsensitiveContains(currentSearch)
            }
            
            // 2. Filter by Category
            if currentCategory != "All" {
                filtered = filtered.filter { $0.sport_category == currentCategory }
            }
            
            // 3. Grouping & Hydration
            var groups: [String: GroupedEvent] = [:]
            
            // Create a lookup map for global channels for faster status access
            // Map Name -> Status, Code -> Status (Normalized: Lowercase + Trimmed)
            var statusMap: [String: String] = [:]
            
            func normalize(_ s: String?) -> String? {
                guard let s = s else { return nil }
                return self.normalizeName(s)
            }
            
            for c in rawChannels {
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
            
            // Re-create formatter in background thread
            let utcFormatter = DateFormatter()
            utcFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            utcFormatter.timeZone = TimeZone(abbreviation: "UTC")
            
            // REAL DATE (No Simulation)
            let simDate = Date()
            
            // Live
            let finalLive = allGroups
                .filter { group in
                    guard group.displayItem.status == "live" else { return false }
                    
                    // Check if event has ended using 'end' field
                    if let endStr = group.displayItem.end,
                       let endDate = utcFormatter.date(from: endStr) {
                        // Hide immediately if current time is past end time
                        if simDate > endDate {
                            return false
                        }
                    }
                    
                    return true
                }
                .sorted { ($0.displayItem.start ?? "") < ($1.displayItem.start ?? "") }
            
            // Upcoming (Filter past events)
            let finalUpcoming = allGroups
                .filter { group in
                    guard group.displayItem.status != "live" else { return false }
                    
                    // Only show events that haven't started yet
                    if let startStr = group.displayItem.start,
                       let startDate = utcFormatter.date(from: startStr) {
                        if simDate > startDate { return false }
                    }
                    
                    return true
                }
                .sorted { ($0.displayItem.start ?? "") < ($1.displayItem.start ?? "") }
            
            // Update UI on Main Thread
            DispatchQueue.main.async {
                self.liveEvents = finalLive
                self.upcomingEvents = finalUpcoming
                completion?()
            }
        }
    }

    
    // --- EPG Helpers ---
    
    private func normalizeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        var s = name.lowercased()
            .components(separatedBy: allowed.inverted).joined()
            
        // Remove suffixes safely (Anchor to end, like Web regex)
        if s.hasSuffix("fhd") { s = String(s.dropLast(3)) }
        else if s.hasSuffix("hd") { s = String(s.dropLast(2)) }
        else if s.hasSuffix("tv") { s = String(s.dropLast(2)) }
        
        return s
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
        // Try cached formatters
        // 1. Full ISO (Internet DateTime + Fractional)
        if let date = isoFormatter.date(from: isoString) {
            return timeFormatter.string(from: date)
        }
        // 2. Standard ISO
        if let date = standardIsoFormatter.date(from: isoString) {
            return timeFormatter.string(from: date)
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
