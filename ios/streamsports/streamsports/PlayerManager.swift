import Foundation
import SwiftUI
import AVKit
import MediaPlayer

class PlayerManager: ObservableObject {
    static let shared = PlayerManager()
    
    @Published var currentChannel: SportsChannel?
    @Published var isPlaying: Bool = false
    @Published var isMiniPlayer: Bool = false
    @Published var offset: CGFloat = 0
    @Published var showControls: Bool = true
    
    var player: AVPlayer?
    
    // Mini Player Config
    let miniHeight: CGFloat = 60
    
    init() {
        setupRemoteCommandCenter()
        setupAudioSession()
    }
    
    func play(channel: SportsChannel) {
        // If already playing this channel, maximize
        if let current = currentChannel, current.id == channel.id {
            withAnimation {
                isMiniPlayer = false
                offset = 0
            }
            return
        }
        
        self.currentChannel = channel
        self.isPlaying = true
        self.isMiniPlayer = false
        self.offset = 0
        
        // Resolve URL if needed, then play
        NetworkManager.shared.resolveStream(url: channel.url) { [weak self] resolvedUrl in
            guard let self = self, let urlStr = resolvedUrl, let url = URL(string: urlStr) else { return }
            
            DispatchQueue.main.async {
                let item = AVPlayerItem(url: url)
                self.player = AVPlayer(playerItem: item)
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
        } else {
            player?.play()
        }
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
}
