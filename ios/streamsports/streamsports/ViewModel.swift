import Foundation
import Combine

class AppViewModel: ObservableObject {
    @Published var channels: [SportsChannel] = []
    @Published var events: [SportsChannel] = [] // Flat list
    @Published var groupedEvents: [GroupedEvent] = []
    @Published var isLoading = false
    
    private let network = NetworkManager.shared
    
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
            self?.events = items
            self?.groupEvents(items)
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func groupEvents(_ items: [SportsChannel]) {
        var groups: [String: GroupedEvent] = [:]
        
        for item in items {
            // Use gameID or match_info as key
            let key = item.gameID ?? item.match_info ?? item.name
            
            if groups[key] == nil {
                groups[key] = GroupedEvent(
                    id: key,
                    displayItem: item,
                    channels: []
                )
            }
            
            groups[key]?.channels.append(item)
        }
        
        // Sort: Live first, then time
        self.groupedEvents = Array(groups.values).sorted {
            if ($0.displayItem.status == "live") != ($1.displayItem.status == "live") {
                return $0.displayItem.status == "live"
            }
            return ($0.displayItem.time ?? "") < ($1.displayItem.time ?? "")
        }
    }
}

struct GroupedEvent: Identifiable {
    let id: String
    let displayItem: SportsChannel
    var channels: [SportsChannel]
}
