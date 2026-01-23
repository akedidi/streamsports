import SwiftUI
import AVKit

struct CustomPlayerOverlay: View {
    @ObservedObject var manager = PlayerManager.shared
    @State private var offset: CGFloat = 0
    
    var body: some View {
        VStack {
            if manager.currentChannel != nil {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // Video Player Area
                        HStack(spacing: 0) {
                            if let player = manager.player {
                                VideoPlayer(player: player)
                                    .frame(width: manager.isMiniPlayer ? 100 : UIScreen.main.bounds.width, height: manager.isMiniPlayer ? 60 : 250)
                            }
                            
                            // Mini Player Title
                            if manager.isMiniPlayer {
                                VStack(alignment: .leading) {
                                    Text(manager.currentChannel?.name ?? "Unknown")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                        .foregroundColor(.white)
                                }
                                .padding(.leading, 10)
                                Spacer()
                                
                                // Mini Controls
                                Button(action: { manager.togglePlayPause() }) {
                                    Image(systemName: manager.player?.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                                        .foregroundColor(.white)
                                        .padding()
                                }
                                
                                Button(action: { manager.close() }) {
                                    Image(systemName: "xmark")
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                        }
                        .background(Color.black)
                        
                        // Full Screen Content
                        if !manager.isMiniPlayer {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 15) {
                                    Text(manager.currentChannel?.name ?? "")
                                        .font(.title2)
                                        .bold()
                                    
                                    HStack {
                                        if let code = manager.currentChannel?.code {
                                            Text(code).padding(5).background(Color.blue.opacity(0.3)).cornerRadius(5)
                                        }
                                        Text("LIVE").foregroundColor(.red).bold()
                                    }
                                    
                                    // Action Buttons Row (AirPlay, PiP placeholder)
                                    HStack(spacing: 20) {
                                        Button(action: {
                                            // PiP handled by AVPlayerViewController automatically usually, 
                                            // but requires specific setup for custom UI.
                                        }) {
                                            VStack {
                                                Image(systemName: "pip.enter")
                                                Text("PiP")
                                            }
                                        }
                                        
                                        Button(action: {
                                            // Native AirPlay routing picker
                                        }) {
                                            VStack {
                                                Image(systemName: "airplayvideo")
                                                Text("AirPlay")
                                            }
                                        }
                                        
                                        Button(action: {
                                            // Chromecast (Placeholder)
                                        }) {
                                            VStack {
                                                Image(systemName: "tv")
                                                Text("Cast")
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                                    
                                    Text("Description")
                                        .font(.headline)
                                    Text(manager.currentChannel?.match_info ?? "No details available")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                            .background(Color(UIColor.systemBackground))
                        }
                    }
                }
                .frame(maxHeight: manager.isMiniPlayer ? 60 : .infinity)
                .background(manager.isMiniPlayer ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
                .offset(y: manager.offset)
                .gesture(
                    DragGesture().onChanged { value in
                        if !manager.isMiniPlayer && value.translation.height > 0 {
                            manager.offset = value.translation.height
                        }
                    }.onEnded { value in
                        if value.translation.height > 100 {
                            withAnimation {
                                manager.isMiniPlayer = true
                                manager.offset = 0
                            }
                        } else {
                            withAnimation {
                                manager.offset = 0
                            }
                        }
                    }
                )
                .onTapGesture {
                    if manager.isMiniPlayer {
                        withAnimation {
                            manager.isMiniPlayer = false
                        }
                    }
                }
                .padding(.bottom, manager.isMiniPlayer ? 50 : 0) // Bottom Tab Bar safe area
            }
        }
        .edgesIgnoringSafeArea(manager.isMiniPlayer ? [] : .all)
    }
}
