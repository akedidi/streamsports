import Foundation
import Combine

class AppViewModel: ObservableObject {
    @Published var channels: [SportsChannel] = []
    
    // Raw Events
    private var allEvents: [SportsChannel] = []
    
    // Processed Events strings
    @Published var liveEvents: [GroupedEvent] = []
    @Published var upcomingEvents: [GroupedEvent] = []
    
    @Published var isLoading = false
    @Published var searchText: String = ""
    
    // Channels Filtering
    @Published var channelSearchText: String = ""
    @Published var selectedCountry: String? = nil
    
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
            self?.filterAndGroupEvents()
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func filterAndGroupEvents() {
        // 1. Filter by Search
        let filtered = searchText.isEmpty ? allEvents : allEvents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.league ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.home_team ?? "").localizedCaseInsensitiveContains(searchText) ||
            ($0.away_team ?? "").localizedCaseInsensitiveContains(searchText)
        }
        
        // 2. Grouping
        var groups: [String: GroupedEvent] = [:]
        for item in filtered {
            let key = item.gameID ?? item.match_info ?? item.name
            
            if groups[key] == nil {
                groups[key] = GroupedEvent(id: key, displayItem: item, channels: [])
            }
            groups[key]?.channels.append(item)
        }
        
        let allGroups = Array(groups.values)
        
        // 3. Separation (Live vs Upcoming) & Sorting
        // Live
        self.liveEvents = allGroups
            .filter { $0.displayItem.status == "live" }
            .sorted { ($0.displayItem.time ?? "") < ($1.displayItem.time ?? "") }
            
        // Upcoming (Filter past events)
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeValue = currentHour * 60 + currentMinute
        
        self.upcomingEvents = allGroups
            .filter { group in
                guard group.displayItem.status != "live" else { return false }
                
                // Parse Time "HH:mm"
                if let timeStr = group.displayItem.time {
                    let parts = timeStr.split(separator: ":")
                    if parts.count == 2,
                       let h = Int(parts[0]), let m = Int(parts[1]) {
                        let eventTimeValue = h * 60 + m
                        
                        // Logic: If event is today, compare time.
                        // Ideally we'd have full date, but data usually gives just time for "today's events"
                        // Simple logic: Display if event time >= current time - 120 mins (allow seeing recently started)
                        // User requested: "displayed from the current time"
                        return eventTimeValue >= currentTimeValue
                    }
                }
                return true // Show if time parse fails (fallback)
            }
            .sorted { ($0.displayItem.time ?? "") < ($1.displayItem.time ?? "") }
    }
}

// Add league convenience
extension SportsChannel {
    var league: String? {
        return self.tournament ?? self.sport_category
    }
}
