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
        NetworkManager.shared.resolveStream(url: channel.url) { [weak self] resolvedUrl in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard let urlStr = resolvedUrl, let url = URL(string: urlStr) else {
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
                
                print("[PlayerManager] Playing URL: \(url)")
                
                // Animate Presentation
                withAnimation(.spring()) {
                    self.currentChannel = channel
                    self.isPlaying = true
                    self.isMiniPlayer = false
                    self.isBuffering = true
                    self.offset = 0
                }
                
                let item = AVPlayerItem(url: url)
                self.player = AVPlayer(playerItem: item)
                
                // Observe Buffering State
                self.timeControlStatusObserver = self.player?.observe(\.timeControlStatus, options: [.new, .initial]) { [weak self] player, _ in
                    DispatchQueue.main.async {
                        self?.isBuffering = (player.timeControlStatus == .waitingToPlayAtSpecifiedRate)
                    }
                }
                
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
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
        nowPlayingInfo[MPMediaItemPropertyArtist] = channel.match_info ?? channel.sport_category ?? "StreamSports"
        
        if let image = channel.image, let url = URL(string: image) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }.resume()
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // MARK: - Chromecast Integration
    private var cancellables = Set<AnyCancellable>()
    
    private func setupChromecastObserver() {
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
        NetworkManager.shared.resolveStream(url: channel.url) { [weak self] resolvedUrl in
            guard let urlStr = resolvedUrl, let url = URL(string: urlStr) else {
                print("[PlayerManager] Failed to resolve proxy URL for casting")
                DispatchQueue.main.async { self?.isBuffering = false }
                return
            }
            
            DispatchQueue.main.async {
                print("[PlayerManager] Casting Proxy URL: \(url)")
                ChromecastManager.shared.cast(url: url, title: channel.name, image: channel.image ?? channel.countryIMG)
                
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
