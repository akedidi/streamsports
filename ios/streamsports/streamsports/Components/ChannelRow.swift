import SwiftUI

// Simple Channel Row (for the Channels tab)
struct ChannelRow: View {
    let channel: SportsChannel
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Badge (Left of Logo)
            let status = getChannelStatus(channel)
            Circle()
                .fill(status == "online" ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.5), lineWidth: 1)
                )
            
            if let img = channel.image, let url = URL(string: img) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        // Error State
                        Image(systemName: "tv").resizable().aspectRatio(contentMode: .fit).foregroundColor(.gray.opacity(0.5)).padding(8)
                    } else {
                        // Loading State
                        Color.gray.opacity(0.1)
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            } else {
                // No Image URL
                Image(systemName: "tv")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(10)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.body)
                    .foregroundColor(.white)
                
                // Country name
                if let code = channel.code {
                    Text(countryName(from: code))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let program = viewModel.getCurrentProgram(for: channel.name) {
                    HStack(spacing: 4) {
                        Text(viewModel.formatTime(program.start))
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(program.title)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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
    
    func countryName(from code: String) -> String {
        let identifier = Locale(identifier: "en_US")
        return identifier.localizedString(forRegionCode: code.uppercased()) ?? code.uppercased()
    }
}
