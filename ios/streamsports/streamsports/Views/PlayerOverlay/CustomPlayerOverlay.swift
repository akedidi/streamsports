import SwiftUI
import AVKit
import Combine

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
    @EnvironmentObject var viewModel: AppViewModel
    
    @State private var dragOffset: CGFloat = 0
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    
    // Internal state
    @State private var isLandscapeMode = false
    @State private var controlsTimer: Timer?
    
    // Constants
    let miniPlayerHeight: CGFloat = 60
    
    // Timer for playback sync
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer() // Pushes overlay to bottom when mini
                
                if let channel = manager.currentChannel {
                    ZStack(alignment: .top) {
                        
                        // BACKGROUND (Fullscreen Only)
                        if !manager.isMiniPlayer {
                            Color.black
                                .edgesIgnoringSafeArea(.all)
                                // If not landscape, maybe rounded corners at top to mimic sheet?
                                // User wants to hide search bar behind, so full opacity.
                                .onTapGesture {
                                    withAnimation {
                                        toggleControls()
                                    }
                                }
                        }
                        
                        // CONTENT
                        VStack(spacing: 0) {
                            
                            // 1. HANDLE (Portrait Only)
                            if !manager.isMiniPlayer && !isLandscapeMode {
                                // Little handle area
                                ZStack {
                                    Color.black
                                    Capsule()
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(width: 40, height: 4)
                                        .padding(.vertical, 8)
                                }
                                .frame(height: 20)
                            }
                            
                            // 2. VIDEO AREA
                            ZStack(alignment: .center) {
                                Color.black
                                
                                if let player = manager.player {
                                    SimplePlayerView(player: player)
                                        .onTapGesture {
                                            if !manager.isMiniPlayer {
                                                toggleControls() 
                                            } else {
                                                maximizePlayer()
                                            }
                                        }
                                } else {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                
                                // CONTROLS OVERLAY
                                if !manager.isMiniPlayer {
                                    // Layer for tap detection to toggle controls
                                     Color.black.opacity(0.001)
                                        .onTapGesture {
                                            toggleControls()
                                        }
                                    
                                    if manager.showControls {
                                        PlayerControlsView(
                                            channel: channel,
                                            manager: manager,
                                            isLandscape: isLandscapeMode,
                                            currentTime: $currentTime,
                                            duration: $duration,
                                            isSeeking: $isSeeking,
                                            toggleFullscreen: toggleFullscreen
                                        )
                                        .transition(.opacity)
                                    }
                                }
                            }
                            // Geometry Logic
                            .frame(
                                width: manager.isMiniPlayer ? 107 : (isLandscapeMode ? nil : geometry.size.width),
                                height: manager.isMiniPlayer ? miniPlayerHeight : (isLandscapeMode ? nil : geometry.size.width * 9/16)
                            )
                            .frame(maxWidth: isLandscapeMode ? .infinity : nil, maxHeight: isLandscapeMode ? .infinity : nil)
                            // Align Video to the right (next to buttons) in MiniPlayer
                            // Buttons (80px) + Padding (10px) = 90px from trailing edge
                            .frame(maxWidth: .infinity, alignment: manager.isMiniPlayer ? .trailing : .center)
                            .padding(.trailing, manager.isMiniPlayer ? 90 : 0)
                            
                            // 3. BELOW VIDEO CONTENT (Portrait Only)
                            if !manager.isMiniPlayer && !isLandscapeMode {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        
                                        // A. Title & Logo Block
                                        HStack(alignment: .top, spacing: 12) {
                                            // Logo
                                            Group {
                                                if let img = channel.countryIMG, let url = URL(string: img) {
                                                    AsyncImage(url: url) { ph in ph.resizable().aspectRatio(contentMode: .fit) } placeholder: { Color.clear }
                                                } else if let img = channel.image, let url = URL(string: img) {
                                                    AsyncImage(url: url) { ph in ph.resizable().aspectRatio(contentMode: .fit) } placeholder: { Color.clear }
                                                } else {
                                                    Image(systemName: "tv").foregroundColor(.gray)
                                                }
                                            }
                                            .frame(width: 44, height: 44)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(6)
                                            
                                            // Title info
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(getRunTitle(channel))
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                
                                                Text(channel.name)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                                
                                                if let tour = channel.tournament {
                                                    Text(tour)
                                                        .font(.caption)
                                                        .foregroundColor(.blue.opacity(0.8))
                                                        .padding(.top, 2)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        .padding(.top, 10)
                                        
                                        Divider().background(Color.white.opacity(0.1))
                                        
                                        // B. SERVERS LIST (Horizontal)
                                        if manager.source == .event {
                                            // Re-implementing sibling channels logic
                                            let siblings = getSiblingChannels(for: channel)
                                            if !siblings.isEmpty {
                                                VStack(alignment: .leading, spacing: 10) {
                                                    Text("Other Servers")
                                                        .font(.caption).bold()
                                                        .foregroundColor(.gray)
                                                        .padding(.horizontal)
                                                    
                                                    ScrollView(.horizontal, showsIndicators: false) {
                                                        HStack(spacing: 8) {
                                                            ForEach(siblings, id: \.url) { sibling in
                                                                Button(action: {
                                                                    manager.play(channel: sibling, source: .event)
                                                                }) {
                                                                    HStack(spacing: 8) {
                                                                        // Mini flag if avail
                                                                        if let code = sibling.code?.lowercased(), let url = URL(string: "https://flagcdn.com/20x15/\(code).png") {
                                                                            AsyncImage(url: url) { ph in ph.resizable() } placeholder: { Color.clear }
                                                                                 .frame(width: 16, height: 12)
                                                                        }
                                                                        
                                                                        VStack(alignment: .leading, spacing: 0) {
                                                                            Text(sibling.channel_name ?? "Server")
                                                                                .font(.system(size: 12, weight: .medium))
                                                                                .foregroundColor(.white)
                                                                            if let lang = sibling.country {
                                                                                Text(lang)
                                                                                    .font(.system(size: 9))
                                                                                    .foregroundColor(.gray)
                                                                            }
                                                                        }
                                                                    }
                                                                    .padding(.horizontal, 10)
                                                                    .padding(.vertical, 8)
                                                                    .background(sibling.url == channel.url ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                                                                    .cornerRadius(8)
                                                                    .overlay(
                                                                        RoundedRectangle(cornerRadius: 8)
                                                                            .stroke(sibling.url == channel.url ? Color.blue : Color.clear, lineWidth: 1)
                                                                    )
                                                                }
                                                            }
                                                        }
                                                        .padding(.horizontal)
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                        } // End Content VStack
                        
                        // 4. Mini Player
                        if manager.isMiniPlayer {
                           MiniPlayerControls(channel: channel, manager: manager, maximizeAction: maximizePlayer)
                        }
                    }
                    // Height Logic
                    .frame(height: manager.isMiniPlayer ? miniPlayerHeight : (isLandscapeMode ? nil : geometry.size.height)) 
                    // Use full geometry height in portrait expanded, to cover search bar
                    
                    .background(Color.black)
                    .edgesIgnoringSafeArea(manager.isMiniPlayer ? [] : .all)
                    
                    // Mini Player Position
                    .offset(y: manager.isMiniPlayer ? -55 : (isLandscapeMode ? 0 : max(0, dragOffset)))
                    
                    // Drag to Minimize
                    .simultaneousGesture(
                        DragGesture().onEnded { value in
                            if !isLandscapeMode && !manager.isMiniPlayer {
                                if value.translation.height > 100 {
                                    minimizePlayer()
                                }
                            }
                        }
                    )
                }
            }
        }
        .onReceive(timer) { _ in
            guard let player = manager.player else { return }
            // Auto-sync status
            if player.timeControlStatus == .playing && !manager.isPlaying {
                // manager.isPlaying = true // optional sync
            }
            if !isSeeking {
                let t = player.currentTime().seconds
                if !t.isNaN { currentTime = t }
                if let d = player.currentItem?.duration.seconds, !d.isNaN, !d.isInfinite {
                    duration = d
                }
            }
        }
        .onChange(of: manager.showControls) { show in
            if show && !manager.isMiniPlayer {
                scheduleAutoHide()
            }
        }
        .onChange(of: manager.currentChannel?.id) { _ in
            // New channel playing, show controls then hide
            manager.showControls = true
            scheduleAutoHide()
        }
    }
    
    // Logic
    func toggleControls() {
        withAnimation {
            manager.showControls.toggle()
        }
        if manager.showControls {
            scheduleAutoHide()
        }
    }
    
    func scheduleAutoHide() {
        // Cancel existing task? In SwiftUI usually using .task or a Timer holder
        // Simple manual timer logic using delay
        guard !manager.isMiniPlayer else { return }
        
        // Invalidation is tricky with simple delay, let's use a task id approach or just simple async
        // Better: Use a dedicated @State for tracking the last interaction time
        // But for now, let's just trigger a delayed block that checks if it should hide
        let currentTimestamp = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            // Check if controls are still shown and user hasn't interacted recently?
            // Simplified: Just hide if playing
            if manager.isPlaying && !isSeeking {
                withAnimation {
                    manager.showControls = false
                }
            }
        }
    }
    
    func toggleFullscreen() {
        if isLandscapeMode {
            DeviceRotation.rotate(to: .portrait)
            isLandscapeMode = false
        } else {
            DeviceRotation.rotate(to: .landscapeRight)
            isLandscapeMode = true
        }
    }
    
    func maximizePlayer() {
        withAnimation(.spring()) {
            manager.isMiniPlayer = false
        }
    }
    
    func minimizePlayer() {
        if isLandscapeMode { toggleFullscreen() }
        withAnimation(.spring()) {
            manager.isMiniPlayer = true
        }
    }
    
    // Helpers
    func getRunTitle(_ item: SportsChannel) -> String {
        // Try to construct "Home vs Away" or fallback
        if let home = item.home_team, let away = item.away_team, !home.isEmpty, !away.isEmpty {
            return "\(home) vs \(away)"
        }
        // Fallback to extraction from name or info
        // Simple heuristic
        return item.name
    }
    
    func getSiblingChannels(for current: SportsChannel) -> [SportsChannel] {
        var candidates: [SportsChannel] = viewModel.channels
        viewModel.liveEvents.forEach { candidates.append(contentsOf: $0.channels) }
        viewModel.upcomingEvents.forEach { candidates.append(contentsOf: $0.channels) }
        
        // Find match
        var siblings: [SportsChannel] = []
        if let gid = current.gameID, !gid.isEmpty {
            siblings = candidates.filter { $0.gameID == gid }
        } else if let info = current.match_info, let tour = current.tournament {
            siblings = candidates.filter { $0.match_info == info && $0.tournament == tour }
        } else {
            // Very fuzzy matching fallback
             siblings = candidates.filter { $0.name == current.name }
        }
        
        // Deduplicate
        var seen = Set<String>()
        return siblings.filter {
            if seen.contains($0.url) { return false }
            seen.insert($0.url)
            return true
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, !seconds.isInfinite else { return "00:00" }
        let total = Int(seconds)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

// REDESIGNED CONTROLS
struct PlayerControlsView: View {
    let channel: SportsChannel
    @ObservedObject var manager: PlayerManager
    let isLandscape: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var isSeeking: Bool
    let toggleFullscreen: () -> Void
    
    var body: some View {
        VStack {
            // TOP BAR
            HStack(alignment: .center) {
                // Minimal info in Fullscreen Overlay
                VStack(alignment: .leading) {
                    Text(channel.channel_name ?? channel.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                
                // AirPlay
                AirPlayButton()
                    .frame(width: 30, height: 30)
            }
            .padding(.top, 10)
            .padding(.horizontal)
            
            Spacer()
            
            // CENTER CONTROLS
            HStack(spacing: 50) {
                Button(action: {
                    manager.seek(to: currentTime - 10)
                }) {
                   Image(systemName: "gobackward.10").font(.system(size: 34)).foregroundColor(.white)
                }
                
                Button(action: { manager.togglePlayPause() }) {
                    Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    manager.seek(to: currentTime + 10)
                }) {
                    Image(systemName: "goforward.10").font(.system(size: 34)).foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // BOTTOM BAR
            VStack(spacing: 6) {
                // Custom Fine Progress Bar
                CustomProgressBar(value: $currentTime, total: duration, onDrag: { dragging in
                    isSeeking = dragging
                    if !dragging { manager.seek(to: currentTime) }
                })
                .frame(height: 20) // Hit area height
                
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2).monospacedDigit()
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        ChromecastButton().frame(width: 24, height: 24)
                        
                        Button(action: {
                            // PiP Action (Placeholder for now as Logic needs AVPictureInPictureController)
                        }) {
                            Image(systemName: "pip.enter")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: toggleFullscreen) {
                           Image(systemName: isLandscape ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color.black.opacity(0.4))
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN else { return "00:00" }
        let total = Int(seconds)
        let s = total % 60
        let m = (total / 60) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// Custom Sleek Progress Bar
struct CustomProgressBar: View {
    @Binding var value: Double
    let total: Double
    let onDrag: (Bool) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)
                    .cornerRadius(1.5)
                
                // Progress
                let progress = total > 0 ? CGFloat(value / total) : 0
                Rectangle()
                    .fill(Color.red)
                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: 3)
                    .cornerRadius(1.5)
                
                // Knob (Only visual)
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .offset(x: (geo.size.width * min(max(progress, 0), 1)) - 6)
            }
            .contentShape(Rectangle()) // Make huge hit area vertically
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        onDrag(true)
                        let percent = min(max(v.location.x / geo.size.width, 0), 1)
                        value = percent * total
                    }
                    .onEnded { _ in
                        onDrag(false)
                    }
            )
        }
    }
}

struct MiniPlayerControls: View {
    let channel: SportsChannel
    @ObservedObject var manager: PlayerManager
    let maximizeAction: () -> Void
    
    var body: some View {
         HStack(spacing: 8) {
            // Logo / Flag
            Group {
                if let img = channel.image, let url = URL(string: img) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().aspectRatio(contentMode: .fit) } else { Color.clear }
                    }
                } else if let img = channel.countryIMG, let url = URL(string: img) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().aspectRatio(contentMode: .fit) } else { Color.clear }
                    }
                } else {
                    Image(systemName: "tv").foregroundColor(.gray)
                }
            }
            .frame(width: 24, height: 24)
            
            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)
            }
            
            Spacer(minLength: 0)
            
            // Video Gap
            Color.clear
                .frame(width: 107, height: 1)
            
            // Buttons
            HStack(spacing: 0) {
                Button(action: { manager.togglePlayPause() }) {
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
        .frame(height: 60)
        .padding(.horizontal, 10)
        .background(Color.clear)
        .overlay(Divider().background(Color.white.opacity(0.1)), alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            maximizeAction()
        }
    }
}

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.activeTintColor = .red
        picker.tintColor = .white
        picker.prioritizesVideoDevices = true
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No updates needed
    }
}
