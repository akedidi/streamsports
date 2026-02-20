import SwiftUI
import AVKit
import Combine

// Enhanced Video Player with PiP Support (Custom Implementation for Manual Control)
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    var isZoomedToFill: Bool = false
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView(player: player)
        view.setZoomed(isZoomedToFill)
        // Setup PiP Controller
        context.coordinator.setupPiP(for: view.playerLayer)
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Ensure player is consistent if view updates
        if uiView.playerLayer.player != player {
            uiView.playerLayer.player = player
        }
        // Update zoom/gravity
        uiView.setZoomed(isZoomedToFill)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var parent: VideoPlayerView
        var pipController: AVPictureInPictureController?
        
        init(_ parent: VideoPlayerView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(togglePiP), name: NSNotification.Name("TogglePiP"), object: nil)
        }
        
        @objc func togglePiP() {
            print("[PiP] Toggle Requested")
            guard let pip = pipController else {
                print("[PiP] Error: No Controller")
                return
            }
            
            if pip.isPictureInPictureActive {
                pip.stopPictureInPicture()
            } else {
                print("[PiP] Starting PiP...")
                pip.startPictureInPicture()
            }
        }
        
        func setupPiP(for layer: AVPlayerLayer) {
            if AVPictureInPictureController.isPictureInPictureSupported() {
                pipController = AVPictureInPictureController(playerLayer: layer)
                pipController?.delegate = self
                pipController?.canStartPictureInPictureAutomaticallyFromInline = true
                print("[PiP] Controller Setup Success")
            } else {
                print("[PiP] Not Supported on this device")
            }
        }
        
        // Delegate methods
        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            print("[PiP] Did Start")
        }
        
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            print("[PiP] Did Stop")
        }
        
        func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
        }
    }
}

class PlayerUIView: UIView {
    let playerLayer = AVPlayerLayer()
    
    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
        backgroundColor = .black
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setZoomed(_ fill: Bool) {
        let gravity: AVLayerVideoGravity = fill ? .resizeAspectFill : .resizeAspect
        if playerLayer.videoGravity != gravity {
            playerLayer.videoGravity = gravity
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

struct CustomPlayerOverlay: View {
    @ObservedObject var manager = PlayerManager.shared
    @EnvironmentObject var viewModel: AppViewModel
    // Observe ChromecastManager to trigger UI updates on connection state change
    @ObservedObject var chromecastManager = ChromecastManager.shared
    
    @State private var dragOffset: CGFloat = 0
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isSeeking = false
    @State private var showCastSheet = false
    // Pinch-to-zoom: false = aspect fit (default), true = aspect fill (ignores safe areas)
    @State private var isZoomedToFill: Bool = false

    
    // Internal state
    @State private var isLandscapeMode = false
    @State private var controlsTimer: Timer?
    
    // Constants
    let miniPlayerHeight: CGFloat = 60
    
    // Timer for playback sync
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {

        GeometryReader { geometry in
            VStack { // Main container
                if manager.isMiniPlayer {
                    Spacer() // Pushes overlay to bottom ONLY when mini
                }
                
                if let channel = manager.currentChannel {
                    // CHECK FOR CHROMECAST CONNECTION
                    Group {
                        if chromecastManager.isConnected {
                        // --- CASTING UI ---
                        ZStack(alignment: .bottom) {
                             if !manager.isMiniPlayer {
                                 // Fullscreen Cast View
                                 CastPlayerView(
                                    channel: channel,
                                    manager: manager,
                                    minimizeAction: minimizePlayer
                                 )
                                 .transition(.move(edge: .bottom))
                                 .gesture(
                                     DragGesture().onEnded { value in
                                         if value.translation.height > 100 {
                                             minimizePlayer()
                                         }
                                     }
                                 )
                             }
                             
                             if manager.isMiniPlayer {
                                 // Mini Cast Dock
                                 MiniCastPlayerView(
                                    channel: channel,
                                    manager: manager,
                                    maximizeAction: maximizePlayer
                                 )
                                 .padding(.bottom, 80) // Tab bar offset
                                 .transition(.move(edge: .bottom))
                             }
                        }
                         // Height & Position Logic for Cast Mode
                        .frame(
                             width: manager.isMiniPlayer ? nil : geometry.size.width,
                             height: manager.isMiniPlayer ? 60 : geometry.size.height
                        )
                        .frame(maxWidth: .infinity) // Full width for mini player
                        .offset(y: manager.isMiniPlayer ? -10 : 0) // Slight lift for dock style
                        
                    } else if chromecastManager.isConnecting {
                        // --- CONNECTING / LOADING STATE ---
                        ZStack {
                            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all) // Use semi-transparent overlay instead of solid black
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5, anchor: .center)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Connecting to Chromecast...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    } else {
                        // --- LOCAL PLAYER UI (Original) ---
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
                                    VideoPlayerView(player: player, isZoomedToFill: isZoomedToFill)
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
                                
                                // Persistent Buffering Spinner (Always visible if buffering)
                                if manager.isBuffering && manager.player != nil {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        // User prefers standard size (removed scaleEffect 2.0)
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
                                            showCastSheet: $showCastSheet,
                                            toggleFullscreen: toggleFullscreen
                                        )
                                        .transition(.opacity)
                                    }
                                }
                            }
                            // Pinch-to-zoom: simultaneous so it works even over controls overlay
                            // simultaneousGesture allows it to coexist with drag and tap gestures
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        if !manager.isMiniPlayer {
                                            print("[Zoom] Pinch value: \(value)")
                                        }
                                    }
                                    .onEnded { value in
                                        guard !manager.isMiniPlayer else { return }
                                        let fill = value > 1.0
                                        print("[Zoom] Pinch ended: \(value) → zoom=\(fill)")
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            isZoomedToFill = fill
                                        }
                                    }
                            )
                            // Geometry Logic
                            .frame(
                                width: manager.isMiniPlayer ? 107 : (isLandscapeMode ? nil : geometry.size.width),
                                height: manager.isMiniPlayer ? miniPlayerHeight : (isLandscapeMode ? nil : geometry.size.width * 9/16)
                            )
                            .frame(maxWidth: isLandscapeMode ? .infinity : nil, maxHeight: isLandscapeMode ? .infinity : nil)
                            // Align Video to the LEFT in MiniPlayer
                            .frame(maxWidth: .infinity, alignment: manager.isMiniPlayer ? .leading : .center)
                            .padding(.leading, manager.isMiniPlayer ? 10 : 0)
                            
                            // 3. BELOW VIDEO CONTENT (Portrait Only)
                            if !manager.isMiniPlayer && !isLandscapeMode {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 20) {
                                        
                                        // A. Title & Logo Block
                                        HStack(alignment: .top, spacing: 12) {
                                            // Logo
                                            Group {
                                                if let img = channel.countryIMG, let url = URL(string: img) {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .success(let image):
                                                            image.resizable().aspectRatio(contentMode: .fit)
                                                        case .failure(_), .empty:
                                                            Image(systemName: "tv").font(.title2).foregroundColor(.gray)
                                                        @unknown default:
                                                            Image(systemName: "tv").font(.title2).foregroundColor(.gray)
                                                        }
                                                    }
                                                } else if let img = channel.image, let url = URL(string: img) {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case .success(let image):
                                                            image.resizable().aspectRatio(contentMode: .fit)
                                                        case .failure(_), .empty:
                                                            Image(systemName: "tv").font(.title2).foregroundColor(.gray)
                                                        @unknown default:
                                                            Image(systemName: "tv").font(.title2).foregroundColor(.gray)
                                                        }
                                                    }
                                                } else {
                                                    Image(systemName: "tv").font(.title2).foregroundColor(.gray)
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
                                                
                                                Text(channel.channel_name ?? channel.name)
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
                                                    Text("Other Channels")
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
                                                                            
                                                                            // Custom Country Name Logic
                                                                            if let code = sibling.code, let name = CountryHelper.name(for: code) {
                                                                                 Text(name)
                                                                                     .font(.system(size: 9))
                                                                                     .foregroundColor(.gray)
                                                                            } else if let lang = sibling.country {
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
                    // Height Logic - explicit height to ensure full screen coverage
                    .frame(height: manager.isMiniPlayer ? miniPlayerHeight : geometry.size.height) 
                    // Use full geometry height in portrait expanded, to cover search bar
                    
                    .background(Color.black)
                    // .edgesIgnoringSafeArea removed here, moved to GeometryReader container for true fullscreen
                    
                    // Mini Player Position
                    .offset(y: manager.isMiniPlayer ? -85 : (isLandscapeMode ? 0 : max(0, dragOffset)))
                    
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
                    .simultaneousGesture(
                        DragGesture().onEnded { value in
                            if !isLandscapeMode && !manager.isMiniPlayer {
                                if value.translation.height > 100 {
                                    minimizePlayer()
                                }
                            }
                        }
                    )
                    .sheet(isPresented: $showCastSheet) {
                        CastDeviceSheet(isPresented: $showCastSheet)
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
                    
                    } // END ELSE (Local Player)
                    } // Close Group
                } // Close if let
             } // Close VStack
        } // Close GeometryReader
        // Only ignore safe area in LANDSCAPE (fullscreen) or MINI player
        // In Portrait Detail mode, we want to respect top safe area (under notch)
        .edgesIgnoringSafeArea(manager.isMiniPlayer || isLandscapeMode ? .all : []) 
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
        .onChange(of: manager.isBuffering) { isBuffering in
            // When buffering finishes, start the timer to hide controls
            if !isBuffering && manager.showControls {
                scheduleAutoHide()
            }
        }
        .persistentSystemOverlays(manager.showControls ? .automatic : .hidden)
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
            // Simplified: Just hide if playing AND NOT BUFFERING
            if manager.isPlaying && !isSeeking && !manager.isBuffering {
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
        withAnimation(.spring(response: 0.12, dampingFraction: 0.75)) {
            manager.isMiniPlayer = false
        }
    }
    
    func minimizePlayer() {
        if isLandscapeMode { toggleFullscreen() }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.75)) {
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
    @Binding var showCastSheet: Bool
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
                if !manager.isBuffering && manager.player != nil {
                     Button(action: {
                        manager.seek(to: currentTime - 10)
                    }) {
                       Image(systemName: "gobackward.10").font(.system(size: 28)).foregroundColor(.white)
                    }
                    
                    Button(action: { manager.togglePlayPause() }) {
                        Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        manager.seek(to: currentTime + 10)
                    }) {
                        Image(systemName: "goforward.10").font(.system(size: 28)).foregroundColor(.white)
                    }
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
                        // Chromecast Button (Always Visible)
                        Button(action: {
                            showCastSheet = true
                        }) {
                            Image("ChromecastIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                        }

                        
                        Button(action: {
                            // Trigger PiP
                             NotificationCenter.default.post(name: NSNotification.Name("TogglePiP"), object: nil)
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
        .onTapGesture {
            withAnimation {
                manager.showControls = false
            }
        }
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
    
    // Video width (16:9 aspect ratio for height 60)
    private let videoWidth: CGFloat = 107
    
    var body: some View {
        HStack(spacing: 8) {
            // Video Gap (left side - video is rendered separately)
            Color.clear
                .frame(width: videoWidth, height: 1)
            
            // Title (to the right of video)
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.white)
            }
            
            Spacer(minLength: 0)
            
            // Buttons (right side)
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
