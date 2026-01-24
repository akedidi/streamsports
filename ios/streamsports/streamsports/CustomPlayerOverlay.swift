import SwiftUI
import AVKit

// Custom AVPlayerLayer wrapper to avoid native controls
struct SimplePlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed for player reference usually, assuming consistent instance
    }
}

class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    
    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect  // Allow aspect fit
        layer.addSublayer(playerLayer)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

struct CustomPlayerOverlay: View {
    @ObservedObject var manager = PlayerManager.shared
// ... (rest of the struct start)
// we need to be careful with the target replacement content to match the file structure.
// I'll put the new structs BEFORE CustomPlayerOverlay

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
                                    // Use Custom SimplePlayerView to avoid native controls showing in mini mode
                                    SimplePlayerView(player: player)
                                        .onTapGesture {
                                            if !manager.isMiniPlayer {
                                                withAnimation {
                                                    manager.showControls.toggle() 
                                                }
                                            } else {
                                                // Pass tap or maximize
                                                withAnimation(.spring()) {
                                                    manager.isMiniPlayer = false
                                                }
                                            }
                                        }
                                } else {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                
                                // OSD Overlays (Hide when controls are hidden)
                                if !manager.isMiniPlayer && manager.showControls {
                                    // Top Right AirPlay (Keep this as requested)
                                    VStack {
                                        HStack {
                                            Spacer()
                                            
                                            // AirPlay Button
                                            Button(action: {
                                                // Trigger route picker safely? 
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
                            .frame(maxWidth: manager.isMiniPlayer ? 107 : .infinity, alignment: manager.isMiniPlayer ? .trailing : .leading)
                            .padding(.trailing, manager.isMiniPlayer ? 80 : 0) // Position video directly left of controls (pause+close = 80px)
                            .allowsHitTesting(true) // Ensure taps work
                            
                            // 3. Info & Controls (Full Screen Overlay)
                            if !manager.isMiniPlayer {
                                ZStack {
                                    // Tap to toggle controls (Invisible layer)
                                    Color.black.opacity(0.001)
                                        .onTapGesture {
                                            withAnimation {
                                                manager.showControls.toggle()
                                            }
                                        }
                                    
                                    if manager.showControls {
                                        VStack(alignment: .leading) {
                                            // TOP BAR
                                            HStack(alignment: .top) {
                                                // Channel Title & Flag
                                                HStack(spacing: 8) {
                                                    // Logo/Flag
                                                    if let img = channel.image, let url = URL(string: img) {
                                                        AsyncImage(url: url) { ph in
                                                            if let image = ph.image {
                                                                image.resizable().aspectRatio(contentMode: .fit)
                                                            } else { Color.clear }
                                                        }
                                                        .frame(width: 30, height: 22)
                                                    } else if let img = channel.countryIMG, let url = URL(string: img) {
                                                        AsyncImage(url: url) { ph in
                                                            if let image = ph.image {
                                                                image.resizable().aspectRatio(contentMode: .fit)
                                                            } else { Color.clear }
                                                        }
                                                        .frame(width: 30, height: 22)
                                                    } else if let code = channel.code?.lowercased(), let url = URL(string: "https://flagcdn.com/w40/\(code).png") {
                                                        AsyncImage(url: url) { ph in
                                                            if let image = ph.image {
                                                                image.resizable().aspectRatio(contentMode: .fit)
                                                            } else { Color.clear }
                                                        }
                                                        .frame(width: 30, height: 22)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(getRunTitle(channel))
                                                            .font(.headline)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.white)
                                                            .lineLimit(2)
                                                        
                                                        Text(channel.tournament ?? channel.sport_category ?? "")
                                                            .font(.subheadline)
                                                            .foregroundColor(Color.gray)
                                                    }
                                                }
                                                .padding(10)
                                                .background(Color.black.opacity(0.5))
                                                .cornerRadius(8)
                                                
                                                Spacer()
                                                
                                                // AirPlay (Top Right, AnisFlix Style)
                                                Button(action: {
                                                    // AirPlay Logic (Route Picker View needed)
                                                }) {
                                                     Image(systemName: "airplayvideo")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(.white)
                                                        .padding(10)
                                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                                }
                                            }
                                            .padding(.top, 40) // Status bar spacing
                                            .padding(.horizontal)
                                            
                                            Spacer()
                                            
                                            // BOTTOM BAR
                                            HStack(spacing: 20) {
                                                // Live Indicator or Time
                                                HStack(spacing: 6) {
                                                    Circle().fill(Color.red).frame(width: 8, height: 8)
                                                    Text("LIVE")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                }
                                                .padding(6)
                                                .background(Color.black.opacity(0.5))
                                                .cornerRadius(4)
                                                
                                                Spacer()
                                                
                                                // Chromecast
                                                ChromecastButton()
                                                    .frame(width: 30, height: 30)
                                                
                                                // PiP
                                                Button(action: {
                                                    // PiP Toggle
                                                }) {
                                                    Image(systemName: "pip.enter")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(.white)
                                                        .padding(8)
                                                }
                                                
                                                // Fullscreen / Minimize
                                                Button(action: {
                                                    withAnimation(.spring()) {
                                                        manager.isMiniPlayer = true
                                                    }
                                                }) {
                                                    Image(systemName: "arrow.down.right.and.arrow.up.left") // Use shrink icon for minimize
                                                        .font(.system(size: 20))
                                                        .foregroundColor(.white)
                                                        .padding(8)
                                                }
                                            }
                                            .padding()
                                            .background(
                                                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                            )
                                        }
                                        .transition(.opacity)
                                    }
                                }
                            }
                        }
                        
                        // 4. Mini Player Info Overlay
                        if manager.isMiniPlayer {
                            HStack(spacing: 8) {
                                // Logo / Flag (LEFT SIDE)
                                Group {
                                    if let img = channel.image, let url = URL(string: img) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fit)
                                            } else { Color.clear }
                                        }
                                    } else if let img = channel.countryIMG, let url = URL(string: img) {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fit)
                                            } else { Color.clear }
                                        }
                                    } else if let code = channel.code?.lowercased(), let url = URL(string: "https://flagcdn.com/w40/\(code).png") {
                                        AsyncImage(url: url) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fit)
                                            } else { Color.clear }
                                        }
                                    } else {
                                        Image(systemName: "tv")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 24, height: 24)
                                
                                // Title
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
                                
                                Spacer() // Push everything else to right
                                
                                // SPACE FOR VIDEO (100px)
                                Spacer().frame(width: 100)
                                
                                // Controls (RIGHT SIDE)
                                HStack(spacing: 0) {
                                    Button(action: { manager.togglePlayPause() }) {
                                        // FIX: Use manager.isPlaying as source of truth
                                        Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                    }
                                    
                                    Button(action: { manager.close() }) {
                                        Image(systemName: "xmark")
                                            .font(.body)
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                    }
                                }
                            }
                            .frame(height: miniPlayerHeight)
                            .padding(.horizontal, 10)
                            .background(Color.clear)
                            .overlay(Divider().background(Color.white.opacity(0.1)), alignment: .top)
                            .contentShape(Rectangle()) // Make entire area tappable (including Spacers)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    manager.isMiniPlayer = false
                                }
                            }
                        }
                    }
                    .frame(height: manager.isMiniPlayer ? miniPlayerHeight : geometry.size.height)
                    .background(
                        // Apply background ONLY when mini player, to the whole container (behind video and text)
                        manager.isMiniPlayer ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.clear
                    )
                    // Offset: When mini, move up (negative y) to sit above TabBar.
                    // TabBar is approx 90pt (content + safe area). Offset -85 ensures it clears top of TabBar.
                    .offset(y: manager.isMiniPlayer ? -85 : 0)
                    .edgesIgnoringSafeArea(.all) 
                    // Drag Gesture to Minimize (Simultaneous to allow gesture over VideoPlayer)
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                // Only allow dragging down
                                if !manager.isMiniPlayer && value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                // Minimize if dragged far enough OR flicked fast enough
                                let dragThreshold: CGFloat = 100
                                let velocityThreshold: CGFloat = 500
                                let predictedEndTranslation = value.predictedEndTranslation.height
                                
                                if value.translation.height > dragThreshold || predictedEndTranslation > velocityThreshold {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        manager.isMiniPlayer = true
                                        dragOffset = 0
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                    .offset(y: manager.isMiniPlayer ? 0 : max(0, dragOffset))
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
