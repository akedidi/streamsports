import SwiftUI
import GoogleCast

struct MiniCastPlayerView: View {
    let channel: SportsChannel
    @ObservedObject var manager: PlayerManager
    @ObservedObject var castManager = ChromecastManager.shared
    
    var maximizeAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
             // Thumbnail
            Group {
                // Logic matching CastPlayerView to show Flag for Events
                let imageUrl = (manager.source == .event ? (channel.countryIMG ?? channel.image) : (channel.image ?? channel.countryIMG))
                
                if let img = imageUrl, let url = URL(string: img) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color(white: 0.2)
                    }
                } else {
                    Image(systemName: "tv")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 40, height: 40)
            .cornerRadius(4)
            .padding(.leading, 12)
            
            Spacer()
            
            // Info
            VStack(alignment: .center, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 4) {
                    Image(systemName: "airplayvideo") // or tv
                        .font(.system(size: 10))
                    
                    if let deviceName = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.device.friendlyName {
                         Text("Casting to \(deviceName)")
                            .font(.caption)
                    } else {
                         Text("Casting to TV")
                            .font(.caption)
                    }
                }
                .foregroundColor(.green)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 16) {
                Button(action: {
                    // Pause Cast Logic
                }) {
                    Image(systemName: "pause.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    castManager.disconnect()
                }) {
                    Image(systemName: "stop.fill") // Square stop
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 60)
        .background(Color(white: 0.12)) // Slightly lighter than pure black
        .cornerRadius(12) // Depending on the style, maybe 0 if it's full width dock
        // If it's the dock style, usually it sits on top of tab bar. 
        // We will let the parent container handle the background/frame specifics if standard mini style is needed.
        // But matching the "pill" style described might mean adding padding around it in the parent.
        // For now, standard rectangular dock content.
        .contentShape(Rectangle())
        .onTapGesture {
            maximizeAction()
        }
    }
}
