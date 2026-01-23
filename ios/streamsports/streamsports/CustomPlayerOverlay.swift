import SwiftUI
import AVKit

struct CustomPlayerOverlay: View {
    @ObservedObject var manager = PlayerManager.shared
    @State private var offset: CGFloat = 0
    
    var body: some View {
        VStack {
            if manager.currentChannel != nil {
                ZStack(alignment: .bottom) {
                    // Full Screen Modal Content
                    if !manager.isMiniPlayer {
                        Color.black.edgesIgnoringSafeArea(.all)
                        
                        VStack(spacing: 0) {
                            // Top Bar (Dismiss)
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation { manager.isMiniPlayer = true }
                                }) {
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            
                            // Player Area
                            if let player = manager.player {
                                VideoPlayer(player: player)
                                    .frame(height: 300)
                                    .background(Color.black)
                            }
                            
                            // Info & Controls
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(manager.currentChannel?.name ?? "")
                                            .font(.title2)
                                            .bold()
                                            .foregroundColor(.white)
                                        
                                        Text(manager.currentChannel?.match_info ?? "")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    // Control Buttons
                                    HStack(spacing: 30) {
                                        // AirPlay (Route Picker)
                                        Button(action: {
                                            // Show AirPlay Picker
                                        }) {
                                            VStack {
                                                Image(systemName: "airplayvideo")
                                                    .font(.system(size: 24))
                                                Text("AirPlay").font(.caption)
                                            }
                                        }
                                        .foregroundColor(.white)
                                        
                                        // Chromecast
                                        ChromecastButton()
                                            .frame(width: 24, height: 24)
                                        
                                        // Fullscreen
                                        Button(action: {
                                            // Toggle pure fullscreen logic (hide UI)
                                        }) {
                                            VStack {
                                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                    .font(.system(size: 24))
                                                Text("Full").font(.caption)
                                            }
                                        }
                                        .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .padding()
                            }
                            Spacer()
                        }
                    }
                    
                    // Mini Player Bar (Modal-like on TabBar)
                    if manager.isMiniPlayer {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                // Video Thumbnail
                                if let player = manager.player {
                                    VideoPlayer(player: player)
                                        .frame(width: 120, height: 68) // 16:9 ish
                                        .allowsHitTesting(false) // Pass touches to bar
                                }
                                
                                // Title Info
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(manager.currentChannel?.name ?? "Playing")
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                        .foregroundColor(.white)
                                    
                                    Text("Tap to expand")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding(.leading, 12)
                                
                                Spacer()
                                
                                // Play/Pause
                                Button(action: { manager.togglePlayPause() }) {
                                    Image(systemName: manager.player?.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding()
                                }
                                
                                // Close
                                Button(action: { manager.close() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                            }
                            .background(Color(UIColor.systemGray6).opacity(0.95))
                            .overlay(Divider(), alignment: .top)
                        }
                        .onTapGesture {
                            withAnimation { manager.isMiniPlayer = false }
                        }
                        .transition(.move(edge: .bottom))
                    }
                }
                .frame(maxHeight: manager.isMiniPlayer ? 68 : .infinity)
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
                            withAnimation { manager.offset = 0 }
                        }
                    }
                )
                // If it's mini player, it sits ABOVE tab bar (bottom padding handled in ContentView usually, 
                // but here it's overlay. We want it effectively "on" the tab bar.)
                .padding(.bottom, manager.isMiniPlayer ? 60 : 0) 
            }
        }
        .edgesIgnoringSafeArea(manager.isMiniPlayer ? [] : .all)
    }
}
