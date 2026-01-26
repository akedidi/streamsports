import SwiftUI

struct EventRow: View {
    let group: GroupedEvent
    let expandAction: () -> Void
    let isExpanded: Bool
    
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            // Main Row
            Button(action: expandAction) {
                HStack(spacing: 12) {
                    // Country Flag (Moved to far left)
                    if let img = group.displayItem.countryIMG, let url = URL(string: img) {
                        AsyncImage(url: url) { ph in ph.resizable() } placeholder: { Color.clear }
                            .frame(width: 20, height: 15)
                            .cornerRadius(2)
                    }
                    
                    // Time / Live Status
                    VStack(spacing: 2) {
                        if group.displayItem.status == "live" {
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    Circle().fill(Color.red).frame(width: 6, height: 6)
                                    Text("LIVE").font(.system(size: 10, weight: .bold)).foregroundColor(.red)
                                }
                                Text(group.displayItem.localTime)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text(group.displayItem.localTime)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 50)
                    
                    // Detail Column
                    VStack(alignment: .leading, spacing: 4) {
                        // Title: Use Match Info or construct from teams
                        Text(getRunTitle(group.displayItem))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            
                        // Subtitle: League / Country
                        HStack(spacing: 6) {
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
                .contentShape(Rectangle()) // Make entire row tappable including Spacer
            }
            .buttonStyle(PlainButtonStyle())
            .animation(nil, value: isExpanded) // Keep header fixed during expansion
            
            // Expanded channels
            if isExpanded {
                ForEach(group.channels, id: \.id) { channel in
                    Button(action: {
                        print("[EventRow] Clicked channel: \(channel.name) (ID: \(channel.id))")
                        PlayerManager.shared.play(channel: channel)
                    }) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                // Status Badge (Left of Flag) - using lookup
                                let status = getChannelStatus(channel)
                                Circle()
                                    .fill(status == "online" ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        Circle().stroke(Color.black.opacity(0.5), lineWidth: 1)
                                    )
                                
                                if let code = channel.code?.lowercased(), let url = URL(string: "https://flagcdn.com/w40/\(code).png") {
                                    AsyncImage(url: url) { ph in ph.resizable() } placeholder: { Color.clear }
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
                            
                            // EPG for expanded item
                            if let program = viewModel.getCurrentProgram(for: channel.name) {
                                HStack(spacing: 4) {
                                    Text("\(viewModel.formatTime(program.start)) -")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    Text(program.title)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                                .padding(.leading, 60)
                                .padding(.bottom, 4)
                            }
                        }
                        .contentShape(Rectangle()) // Make entire button area clickable
                    }
                    .buttonStyle(PlainButtonStyle()) // Fix for click targets in List
                    Divider().background(Color.gray.opacity(0.2)).padding(.leading, 60)
                }
            }
        }
    }
    
    // Get status by looking up channel name in the channels list
    func getChannelStatus(_ item: SportsChannel) -> String {
        let channelName = (item.channel_name ?? item.name).lowercased()
        
        // Lookup in viewModel.channels by name
        if let matched = viewModel.channels.first(where: { 
            $0.name.lowercased() == channelName || 
            channelName.contains($0.name.lowercased()) ||
            $0.name.lowercased().contains(channelName)
        }) {
            return matched.status?.lowercased() ?? "offline"
        }
        
        // Fallback to item's own status
        return item.status?.lowercased() ?? "offline"
    }
    
    func getRunTitle(_ item: SportsChannel) -> String {
        // Prefer "Team A vs Team B" if available, but show single name if identical
        if let home = item.home_team, let away = item.away_team, !home.isEmpty, !away.isEmpty {
            if home == away {
                return home // Show just the name if both teams are the same (e.g., "Simulcast")
            }
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
