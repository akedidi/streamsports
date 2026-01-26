import SwiftUI
import GoogleCast

struct CastPlayerView: View {
    let channel: SportsChannel
    @ObservedObject var manager: PlayerManager
    @ObservedObject var castManager = ChromecastManager.shared
    
    // UI State for transitions
    var minimizeAction: () -> Void
    // Helper for title logic to avoid ViewBuilder errors
    var mainTitle: String {
        if let home = channel.home_team, let away = channel.away_team, !home.isEmpty, !away.isEmpty {
            return "\(home) vs \(away)"
        } else {
            return channel.name
        }
    }
    
    var body: some View {
        ZStack {
            // 1. Base Layer: Opaque Black (Hides underlying UI)
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // 2. Background Image Layer (Blurred)
            let bgImageUrl = (manager.source == .event ? (channel.countryIMG ?? channel.image) : (channel.image ?? channel.countryIMG))
            if let bgImg = bgImageUrl, let url = URL(string: bgImg) {
                AsyncImage(url: url) { image in
                    image.resizable()
                         .aspectRatio(contentMode: .fill)
                         .edgesIgnoringSafeArea(.all)
                } placeholder: {
                    Color.clear
                }
                .blur(radius: 40) // The "Effect Blur" requested
                .overlay(Color.black.opacity(0.5)) // Dimming for readability
            }
            
            // 3. Content
            VStack(spacing: 30) {
                // Top Handle for visual cue (optional)
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                
                Spacer()
                
                // Poster Art / Image
                // Priority: Event -> Flag (countryIMG), Channel -> Logo (image)
                let imageUrl = (manager.source == .event ? (channel.countryIMG ?? channel.image) : (channel.image ?? channel.countryIMG))
                
                if let img = imageUrl, let url = URL(string: img) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color(white: 0.1)
                            .overlay(ProgressView().tint(.white))
                    }
                    // Smaller size as requested (was 220)
                    .frame(width: 120, height: 90)
                    .background(Color.clear)
                    // Modern shadow and slight rounding
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.6), radius: 15, x: 0, y: 8)
                    .padding(.bottom, 20)
                } else {
                     // Default Icon
                    Image(systemName: "tv")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 100, height: 100)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                        .padding(.bottom, 20)
                }
                
                // Title & Status
                VStack(spacing: 8) {
                    // 1. Tournament
                    if let tour = channel.tournament {
                        Text(tour.uppercased())
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                            .tracking(1)
                    }
                    
                    // 2. Event Name
                    
                    Text(mainTitle)
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // 3. Channel Name (Only if different from Main Title)
                    if let channelName = channel.channel_name, !channelName.isEmpty, channelName.lowercased() != mainTitle.lowercased() {
                        Text(channelName)
                            .font(.headline)
                            .foregroundColor(.blue) // Make it distinct
                            .padding(.top, 2)
                    }
                    
                    HStack(spacing: 6) {
                        Text("Casting to")
                            .foregroundColor(.gray)
                        if let deviceName = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.device.friendlyName {
                            Text(deviceName)
                                .foregroundColor(.white)
                                .bold()
                        } else {
                            Text("Device")
                                .foregroundColor(.white)
                                .bold()
                        }
                    }
                    .font(.subheadline)
                }
                
                // Spacer for layout balance
                Spacer()
                
                // Controls
                VStack(spacing: 40) {
                    // Playback Controls (Simplified for Casting)

                    if manager.isBuffering {
                         ProgressView()
                             .progressViewStyle(CircularProgressViewStyle(tint: .white))
                             .scaleEffect(1.5)
                             .padding(.bottom, 20)
                    } else {
                        HStack(spacing: 50) {
                            // Rewind 10 (Simulated or supported?) - Keeping it visual for now
                            Button(action: {
                                // Implement seek backward logic for Cast if available
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray) // Dimmed as complex seek might vary
                            }
                            
                            // Play/Pause (Visual toggle mostly, real sync needs Cast Channel)
                            Button(action: {
                                // Toggle cast playback logic here
                            }) {
                               Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(.white)
                            }
                            
                            // Forward 10
                             Button(action: {
                                // Implement seek forward logic for Cast if available
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Bottom Actions
                    HStack {
                         Spacer()
                         
                        // Stop Casting
                        Button(action: {
                            castManager.disconnect()
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: "stop.circle")
                                    .font(.system(size: 44))
                                Text("Stop Casting")
                                    .font(.headline)
                            }
                            .foregroundColor(.red) // Make it more distinct? or Keep White
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
        // Swipe down gestures handled by parent or simultaneous gesture here
    }
}
