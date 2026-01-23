import SwiftUI
import AVKit

struct CustomPlayerOverlay: View {
    @ObservedObject var manager = PlayerManager.shared
    @State private var dragOffset: CGFloat = 0
    
    // Constants
    let miniPlayerHeight: CGFloat = 60
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                if let channel = manager.currentChannel {
                    ZStack(alignment: .top) {
                        // Background (Full Screen Card)
                        if !manager.isMiniPlayer {
                            Color(red: 0.05, green: 0.05, blue: 0.05) // Deep Dark Background
                                .cornerRadius(20, corners: [.topLeft, .topRight])
                                .shadow(radius: 10)
                                .edgesIgnoringSafeArea(.all)
                                // Handle tap to toggle controls
                                .onTapGesture {
                                    withAnimation {
                                        manager.showControls.toggle()
                                    }
                                }
                        }
                        
                        // Content
                        VStack(spacing: 0) {
                            // 1. Handle (Only in Full)
                            if !manager.isMiniPlayer {
                                Capsule()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 5)
                                    .padding(.top, 10)
                                    .padding(.bottom, 10)
                            }
                            
                            // 2. Video Area
                            ZStack(alignment: .topLeading) {
                                Color.black
                                
                                if let player = manager.player {
                                    VideoPlayer(player: player)
                                        .onTapGesture {
                                            withAnimation {
                                                manager.showControls.toggle() 
                                            }
                                        }
                                } else {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                
                                // OSD Overlays (Hide when controls are hidden)
                                if !manager.isMiniPlayer && manager.showControls {
                                    // Channel Title (Top Left)
                                    Text(channel.name)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(4)
                                        .padding(10)
                                        .transition(.opacity)
                                    
                                    // AirPlay (Top Right)
                                    VStack {
                                        HStack {
                                            Spacer()
                                            
                                            // AirPlay Button
                                            Button(action: {
                                                // Trigger route picker safely? 
                                                // SwiftUI doesn't have a direct button, usually needs UIViewRepresentable
                                            }) {
                                                 Image(systemName: "airplayvideo")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .padding(10)
                                                    .background(Color.black.opacity(0.4))
                                                    .clipShape(Circle())
                                            }
                                            .padding(10)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                            .frame(height: manager.isMiniPlayer ? miniPlayerHeight : geometry.size.width * 9/16)
                            .frame(maxWidth: manager.isMiniPlayer ? 100 : .infinity, alignment: .leading)
                            
                            // 3. Info & Controls (Full Screen Only)
                            if !manager.isMiniPlayer {
                                VStack(alignment: .leading, spacing: 24) {
                                    // Match Details (Always visible? User said "se cacher en meme temps". 
                                    // Usually metadata stays, but user said "le titre de la chaine... se cacher en meme temps que les autres controleurs". 
                                    // But the Event Details are below. Let's assume standard behavior: details stay or toggle?
                                    // User said "les autres bouton... se cachent". 
                                    // Let's toggle everything for cleanliness implicitly requested.
                                    
                                    if manager.showControls {
                                        // Title (Teams)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(getRunTitle(channel))
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .lineLimit(2)
                                            
                                            HStack(spacing: 6) {
                                                if let code = channel.code?.lowercased(), let url = URL(string: "https://flagcdn.com/w40/\(code).png") {
                                                    AsyncImage(url: url) { ph in ph.resizable() } placeholder: { Color.clear }
                                                        .frame(width: 18, height: 13.5)
                                                }
                                                Text(channel.tournament ?? channel.sport_category ?? "")
                                                    .font(.subheadline)
                                                    .foregroundColor(Color.blue.opacity(0.9))
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.top, 10)
                                        .transition(.opacity)
                                        
                                        Spacer()
                                        
                                        // Bottom Controls Row (Right Aligned: CC -> PiP -> Full)
                                        HStack(spacing: 20) {
                                            Spacer()
                                            
                                            // Chromecast
                                            ChromecastButton()
                                                .frame(width: 24, height: 24)
                                                .foregroundColor(.white)
                                            
                                            // PiP
                                            Button(action: {
                                                // PiP logic is native in AVPlayerViewController usually.
                                            }) {
                                                Image(systemName: "pip.enter")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            // Fullscreen
                                            Button(action: {
                                                 // Fullscreen toggle logic
                                            }) {
                                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .padding(.horizontal, 24) // bit more padding from edge
                                        .padding(.bottom, 40)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                }
                            }
                        }
                        
                        // 4. Mini Player Info Overlay
                        if manager.isMiniPlayer {
                            HStack {
                                Spacer().frame(width: 110)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.name)
                                        .font(.subheadline).bold()
                                        .lineLimit(1)
                                        .foregroundColor(.white)
                                    Text(getRunTitle(channel))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                                Spacer()
                                
                                Button(action: { manager.togglePlayPause() }) {
                                    Image(systemName: manager.player?.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                                
                                Button(action: { manager.close() }) {
                                    Image(systemName: "xmark")
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .padding()
                                }
                            }
                            .frame(height: miniPlayerHeight)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .overlay(Divider().background(Color.white.opacity(0.1)), alignment: .top)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    manager.isMiniPlayer = false
                                }
                            }
                        }
                    }
                    .frame(height: manager.isMiniPlayer ? miniPlayerHeight : geometry.size.height)
                    .offset(y: manager.isMiniPlayer ? -60 : max(0, dragOffset))
                    .edgesIgnoringSafeArea(.all) // Ensure we cover the tab bar which is likely in safe area
                    // Drag Gesture to Minimize
                    .gesture(
                        DragGesture().onChanged { value in
                            if !manager.isMiniPlayer && value.translation.height > 0 {
                                dragOffset = value.translation.height
                            }
                        }.onEnded { value in
                            if value.translation.height > 100 {
                                withAnimation(.spring()) {
                                    manager.isMiniPlayer = true
                                    dragOffset = 0
                                }
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                    )
                }
            }
            .edgesIgnoringSafeArea(.bottom) // Explicitly ignore bottom safe area for the wrapper VStack
        }
    }
    
    func getRunTitle(_ item: SportsChannel) -> String {
        if let home = item.home_team, let away = item.away_team, !home.isEmpty, !away.isEmpty {
            return "\(home) vs \(away)"
        }
        if let info = item.match_info {
            if let tournament = item.tournament, info.starts(with: tournament) {
                return String(info.dropFirst(tournament.count)).trimmingCharacters(in: CharacterSet(charactersIn: " -"))
            }
            return info
        }
        return item.name
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
