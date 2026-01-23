import SwiftUI

struct ChannelRow: View {
    let channel: SportsChannel
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: channel.image ?? "")) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(channel.name)
                    .font(.headline)
                    .lineLimit(1)
                    
                HStack {
                    if let code = channel.code {
                        Text(code)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    if channel.status == "online" {
                        Text("● Online")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("○ Offline")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// EventRow adapted for Play Action
struct EventRow: View {
    let group: GroupedEvent
    let expandAction: () -> Void
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            // Main Row
            Button(action: expandAction) {
                HStack {
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
                    .frame(width: 50)
                    
                    VStack(alignment: .leading) {
                        Text(formatTitle(group.displayItem.name))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            
                        HStack {
                            if let img = group.displayItem.countryIMG, let url = URL(string: img) {
                                AsyncImage(url: url) { ph in ph.resizable() } placeholder: { Color.clear }
                                    .frame(width: 16, height: 12)
                            }
                            Text(group.displayItem.tournament ?? group.displayItem.sport_category ?? "")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    if group.channels.count > 1 {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundColor(.gray)
                    }
                }
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
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(channel.code ?? "")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 60)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    func formatTitle(_ name: String) -> String {
        guard let idx = name.range(of: "-") else { return name }
        return String(name[..<idx.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
}

