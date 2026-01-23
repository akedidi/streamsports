import SwiftUI

struct CustomSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search events, teams...", text: $text)
                .foregroundColor(.white)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// Custom Tab Bar to replace "moche" standard one
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            Spacer()
            // Events Tab
            Button(action: { selectedTab = 0 }) {
                VStack(spacing: 4) {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 20, weight: selectedTab == 0 ? .bold : .regular))
                    Text("Events")
                        .font(.caption2)
                }
                .foregroundColor(selectedTab == 0 ? .blue : .gray)
            }
            Spacer()
            Spacer()
            // Channels Tab
            Button(action: { selectedTab = 1 }) {
                VStack(spacing: 4) {
                    Image(systemName: "tv")
                        .font(.system(size: 20, weight: selectedTab == 1 ? .bold : .regular))
                    Text("Channels")
                        .font(.caption2)
                }
                .foregroundColor(selectedTab == 1 ? .blue : .gray)
            }
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 30) // Safe area
        .background(Color(red: 0.1, green: 0.1, blue: 0.1).edgesIgnoringSafeArea(.bottom))
    }
}

struct EventRow: View {
    let group: GroupedEvent
    let expandAction: () -> Void
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            // Main Row
            Button(action: expandAction) {
                HStack(spacing: 12) {
                    // Time / Live Status
                    VStack {
                        if group.displayItem.status == "live" {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text("LIVE").font(.caption2).foregroundColor(.red).bold()
                        } else {
                            Text(group.displayItem.time ?? "TBD")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 45)
                    
                    // Detail Column
                    VStack(alignment: .leading, spacing: 4) {
                        // Title: Use Match Info or construct from teams
                        Text(getRunTitle(group.displayItem))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            
                        // Subtitle: League / Country
                        HStack(spacing: 6) {
                            if let img = group.displayItem.countryIMG, let url = URL(string: img) {
                                AsyncImage(url: url) { ph in ph.resizable() } placeholder: { Color.clear }
                                    .frame(width: 16, height: 12)
                            }
                            Text(group.displayItem.tournament ?? group.displayItem.sport_category ?? "")
                                .font(.caption)
                                .foregroundColor(Color.blue.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    if group.channels.count > 1 {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded channels
            if isExpanded {
                ForEach(group.channels, id: \.id) { channel in
                    Button(action: {
                        PlayerManager.shared.play(channel: channel)
                    }) {
                        HStack {
                            if let code = channel.code?.lowercased(), let url = URL(string: "https://flagcdn.com/w40/\(code).png") {
                                AsyncImage(url: url) { ph in ph.resizable() } placeholder: { Color.gray }
                                    .frame(width: 20, height: 15)
                            }
                            Text(channel.channel_name ?? channel.name)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            Text(channel.code ?? "")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding(.leading, 60)
                        .padding(.vertical, 8)
                    }
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 60)
                }
            }
        }
    }
    
    func getRunTitle(_ item: SportsChannel) -> String {
        // Prefer "Team A vs Team B" if available
        if let home = item.home_team, let away = item.away_team, !home.isEmpty, !away.isEmpty {
            return "\(home) vs \(away)"
        }
        // Else use match_info without the tournament prefix (clever parsing)
        if let info = item.match_info {
            // Usually "Tournament - A vs B". Remove "Tournament - "
            if let tournament = item.tournament, info.starts(with: tournament) {
                return String(info.dropFirst(tournament.count)).trimmingCharacters(in: CharacterSet(charactersIn: " -"))
            }
            return info
        }
        // Fallback to name parsing
        guard let idx = item.name.range(of: "-") else { return item.name }
        return String(item.name[..<idx.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
}

// Simple Channel Row (for the other tab)
struct ChannelRow: View {
    let channel: SportsChannel
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: channel.image ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 44, height: 44)
            .cornerRadius(6)
            
            Text(channel.name)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
