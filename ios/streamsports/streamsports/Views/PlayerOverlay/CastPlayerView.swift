import SwiftUI
import GoogleCast

struct CastPlayerView: View {
    let channel: SportsChannel
    @ObservedObject var manager: PlayerManager
    @ObservedObject var castManager = ChromecastManager.shared
    
    // UI State for transitions
    var minimizeAction: () -> Void
    
    var body: some View {
        ZStack {
            // Background - Blurred Image
            GeometryReader { geo in
                if let urlStr = (manager.source == .event ? (channel.countryIMG ?? channel.image) : (channel.image ?? channel.countryIMG)),
                   let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .blur(radius: 40)
                                .overlay(Color.black.opacity(0.6))
                        } else {
                            Color.black
                        }
                    }
                } else {
                    Color.black // Fallback background
                }
            }
            .edgesIgnoringSafeArea(.all)
            
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
                    .frame(width: 220, height: 220)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                } else {
                     // Default Icon
                    Image(systemName: "tv")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 220, height: 220)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                
                // Title & Status
                VStack(spacing: 8) {
                    Text(channel.name)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
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
