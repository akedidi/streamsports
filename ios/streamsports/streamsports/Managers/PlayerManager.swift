import Foundation
import Combine
import SwiftUI
import AVKit
import MediaPlayer
import CoreMedia

enum PlaybackSource {
    case event
    case channelList
}

class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    @Published var currentChannel: SportsChannel?
    @Published var isPlaying: Bool = false
    @Published var isMiniPlayer: Bool = false
    @Published var offset: CGFloat = 0
    @Published var showControls: Bool = true
    @Published var isBuffering: Bool = true // Default to true when starting
    
    // Track where playback started from
    var source: PlaybackSource = .event
    
    var player: AVPlayer?
    private var timeControlStatusObserver: NSKeyValueObservation?
    
    // Mini Player Config
    let miniHeight: CGFloat = 60
    
    init() {
        setupRemoteCommandCenter()
        setupAudioSession()
        setupChromecastObserver()
    }
    
    func play(channel: SportsChannel, source: PlaybackSource = .event) {
        let isSameChannel = (currentChannel?.id == channel.id)
        let isLocallyPlaying = (player != nil && isPlaying)
        let isCasting = ChromecastManager.shared.isConnected
        
        // 1. Existing Playback Check (Maximize if already active)
        if isSameChannel {
            // If we are casting this channel OR playing it locally, just maximize.
            // If we are disconnected and not playing (Resume scenario), we MUST fall through.
            if isLocallyPlaying || isCasting {
                withAnimation {
                    isMiniPlayer = false
                    offset = 0
                }
                return
            }
        }
        
        // 2. Reset / Prepare
        self.player?.pause()
        self.player = nil
        self.isPlaying = false
        
        self.currentChannel = channel
        self.source = source
        self.isMiniPlayer = false
        self.offset = 0
        
        // 3. Dispatch to Cast or Local
        if isCasting {
             // If connected to Cast, load media there
             self.castCurrentChannel()
             // Ensure UI shows playing state for Cast
             self.isPlaying = true 
             return
        }
        
        // 4. Local Playback Logic
        print("[PlayerManager] Resolving stream for: \(channel.url)")
        NetworkManager.shared.resolveStream(url: channel.url) { [weak self] resolvedUrl, rawUrl, cookie, userAgent in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Determine playback mode:
                // - If resolvedUrl exists: Use proxy (backend handles headers)
                // - If only rawUrl exists: Direct playback with injected headers
                let isDirectPlayback = (resolvedUrl == nil && rawUrl != nil)
                let urlToUseStr = isDirectPlayback ? rawUrl : (resolvedUrl ?? rawUrl)
                
                guard let urlStr = urlToUseStr, let url = URL(string: urlStr) else {
                    print("[PlayerManager] Failed to resolve URL")
                    return
                }
                
                // Verify we are still trying to play the same channel
                guard self.currentChannel?.id == channel.id else { return }
                
                // Double check we didn't start casting in the meantime
                if ChromecastManager.shared.isConnected {
                    self.castCurrentChannel()
                    return
                }
                
                print("[PlayerManager] Playing URL: \(url) (Mode: \(isDirectPlayback ? "DIRECT" : "PROXY"))")
                
                
                // Animate Presentation
                withAnimation(.spring()) {
                    self.currentChannel = channel
                    self.isPlaying = true
                    self.isMiniPlayer = false
                    self.isBuffering = true
                    self.offset = 0
                }
                
                // Create AVURLAsset - with headers for direct playback
                let finalUrl: URL
                
                if isDirectPlayback {
                    // --- CDN-LIVE SPECIAL ---
                    if url.absoluteString.contains("cdn-live") || url.absoluteString.contains("cdn-google") || url.absoluteString.contains("cdn-live.ru") {
                         // We MUST use LocalProxyServer for cdn-live.
                         // Direct Playback with AVURLAssetHTTPHeaderFieldsKey drops headers on subsequent 
                         // live playlist refreshes and segment requests, leading to 401 (-15514) stalls.
                         LocalProxyServer.shared.start()
                         let proxyUrl = LocalProxyServer.shared.getProxyUrl(for: url.absoluteString, cookie: cookie, userAgent: userAgent, referer: "https://cdn-live.tv/")
                         finalUrl = URL(string: proxyUrl)!
                         print("🔄 [PlayerManager] Using Local Proxy for cdn-live to guarantee Cookie persistence")
                    } else if let cookie = cookie {
                        // Local Proxy needed for Cookie support (non-cdn-live)
                        LocalProxyServer.shared.start() // Ensure started
                        let proxyUrl = LocalProxyServer.shared.getProxyUrl(for: url.absoluteString, cookie: cookie, userAgent: userAgent, referer: "https://cdn-live.tv/")
                        finalUrl = URL(string: proxyUrl)!
                        print("[PlayerManager] Using Local Proxy (UA: \(userAgent != nil), Ref: https://cdn-live.tv/)")
                    } else {
                        // Direct (cdn-live.tv: token in URL, no proxy needed)
                        finalUrl = url
                        print("[PlayerManager] Using Direct Playback without proxy")
                    }
                } else {
                    // PROXY PLAYBACK: NetworkManager returned a backend proxy URL
                    finalUrl = url
                    print("[PlayerManager] Using Backend Proxy Playback")
                }
                
                let asset = AVURLAsset(url: finalUrl)
                
                let item = AVPlayerItem(asset: asset)
                self.player = AVPlayer(playerItem: item)
                
                // Observe Buffering State
                self.timeControlStatusObserver = self.player?.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
                    DispatchQueue.main.async {
                        self?.isBuffering = (player.timeControlStatus == .waitingToPlayAtSpecifiedRate)
                        self?.updateNowPlayingState()
                    }
                }
                
                self.player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
                
                self.player?.play()
                self.setupNowPlaying(channel: channel)
            }
        }
    }
    
    func close() {
        self.player?.pause()
        self.player = nil
        self.currentChannel = nil
        self.isPlaying = false
    }
    
    func togglePlayPause() {
        if player?.timeControlStatus == .playing {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }
    
    func seek(to seconds: Double) {
        let targetTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: targetTime)
    }
    
    // MARK: - Background Audio & Lock Screen
    private func setupAudioSession() {
        do {
            // Use .playback category with .default mode.
            // .moviePlayback sometimes restricts background audio if video is present but screen is off?
            // .default is safer for general media apps wanting background audio.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session:", error)
        }
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            return .success
        }
    }
    
    private func setupNowPlaying(channel: SportsChannel) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = channel.name
        
        // Subtitle logic matching UI
        if let home = channel.home_team, let away = channel.away_team {
            nowPlayingInfo[MPMediaItemPropertyArtist] = "\(home) vs \(away)"
        } else {
            nowPlayingInfo[MPMediaItemPropertyArtist] = channel.match_info ?? channel.sport_category ?? "StreamSports"
        }
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = player?.currentItem?.duration.seconds ?? 0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds ?? 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo // Set initial info
        
        // Artwork Logic
        let imageUrl = (source == .event ? (channel.countryIMG ?? channel.image) : (channel.image ?? channel.countryIMG))
        print("[PlayerManager] LockScreen Artwork URL: \(imageUrl ?? "nil")")
        

        
        guard let image = imageUrl, let url = URL(string: image), !image.isEmpty else {
            setDefaultArtwork()
            return
        }
        
        // Remove SVG check as user confirmed images work in app (likely PNG/JPG)
        downloadArtwork(from: url)
    }
    
    private func downloadArtwork(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let data = data, let img = UIImage(data: data) {
                // Resize and Composite on Dark Background
                let finalImage = self?.createSquareImage(from: img) ?? img
                
                DispatchQueue.main.async {
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                    currentInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: finalImage.size) { _ in finalImage }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            } else {
                 print("[PlayerManager] Failed to download artwork: \(error?.localizedDescription ?? "Invalid Data")")
                 self?.setDefaultArtwork()
            }
        }.resume()
    }
    
    private func createSquareImage(from image: UIImage) -> UIImage {
        let size = CGSize(width: 500, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 1. Fill Dark Background
            UIColor(white: 0.1, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 2. Calculate aspect fit rect for the logo
            let aspect = image.size.width / image.size.height
            var drawRect: CGRect
            
            if aspect > 1 {
                // Wide image
                let w = size.width * 0.8
                let h = w / aspect
                drawRect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
            } else {
                // Tall or square image
                let h = size.height * 0.8
                let w = h * aspect
                drawRect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
            }
            
            // 3. Draw image centered
            image.draw(in: drawRect)
        }
    }
    
    private func setDefaultArtwork() {
        DispatchQueue.main.async {
            var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
            // Ensure we use the generated placeholder which has a dark background
            if let img = self.renderPlaceholderImage() {
                 currentInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
        }
    }
    
    private func renderPlaceholderImage() -> UIImage? {
        let size = CGSize(width: 500, height: 500)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background
            UIColor(white: 0.1, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Symbol
            if let symbol = UIImage(systemName: "tv.fill")?.withTintColor(.white) {
                 // Scale symbol to fit nicely
                 let symSize = CGSize(width: 250, height: 180) // approx aspect
                 let rect = CGRect(
                    x: (size.width - symSize.width) / 2,
                    y: (size.height - symSize.height) / 2,
                    width: symSize.width,
                    height: symSize.height
                 )
                 symbol.draw(in: rect.insetBy(dx: -20, dy: -20)) // Naive drawing, simpler to use text or just fill
            }
            
            // Text Fallback (StreamSports)
            let text = "StreamSports"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 60, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2 + 100,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
        }
    }
    
    private func updateNowPlayingState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player?.currentTime().seconds ?? 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - Chromecast Integration
    private var cancellables = Set<AnyCancellable>()
    
    private func setupChromecastObserver() {
        // Disconnect player from AVPlayerLayer when entering background to avoid auto-pause?
        // Actually, preventing auto-pause is handled by setting:
        // player?.allowsExternalPlayback = true (default)
        // AND having the AudioSession active.
        
        // Ensure player is not paused when view disappears
        // In SwiftUI VideoPlayer, this happens automatically sometimes.
        // A common fix is to ensure the AVPlayer is stored in the manager (done)
        // and NOT solely owned by the View.
        
        ChromecastManager.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if isConnected {
                   // logic handled by castCurrentChannel called only once usually, 
                   // but we might need to be careful not to loop if it toggles.
                   // Actually castCurrentChannel checks currentChannel existence.
                   self?.castCurrentChannel()
                } else {
                    // DISCONNECTED -> Resume Local Playback
                    self?.resumeLocalPlayback()
                }
            }
            .store(in: &cancellables)
    }
    
    private func resumeLocalPlayback() {
        guard let channel = currentChannel, !isPlaying else { return }
        print("[PlayerManager] Resuming local playback for: \(channel.name)")
        
        // Simply re-call play logic
        self.play(channel: channel, source: self.source)
    }
    
    private func castCurrentChannel() {
        guard let channel = currentChannel else { return }
        
        print("[PlayerManager] Preparing to cast: \(channel.name)")
        
        // Show loading state while resolving
        DispatchQueue.main.async {
            self.isBuffering = true
        }
        
        // Resolve the PROXY URL (same as web)
        NetworkManager.shared.resolveStream(url: channel.url) { [weak self] proxyUrl, rawUrl, _, _ in
            // Fallback to rawUrl if proxyUrl is missing.
            // Priority: PROXY (Fixed to handle headers/segments) -> RAW (Backup)
            guard let urlStr = proxyUrl ?? rawUrl, let url = URL(string: urlStr) else {
                print("[PlayerManager] Failed to resolve URL for casting (Proxy: \(proxyUrl ?? "nil"), Raw: \(rawUrl ?? "nil"))")
                DispatchQueue.main.async { self?.isBuffering = false }
                return
            }
            
            DispatchQueue.main.async {
                print("[PlayerManager] Casting URL: \(url) (isRaw: \(rawUrl != nil))")
                ChromecastManager.shared.cast(url: url, title: channel.name, image: channel.image ?? channel.countryIMG, isLive: true)
                
                // Release local player resources completely
                self?.player?.replaceCurrentItem(with: nil)
                self?.player = nil
                self?.isPlaying = false
                
                // Assume casting started successfully after brief delay or rely on Cast Manager events?
                // For now, simple delay to simulate load completion, or let Cast view handle "buffering" if SDK provides api.
                // We'll just turn off buffering after 1.5s to show UI transition.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self?.isBuffering = false
                }
            }
        }
    }
}
