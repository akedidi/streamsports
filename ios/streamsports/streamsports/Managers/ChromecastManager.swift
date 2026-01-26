import Foundation
import Combine
import SwiftUI

// This is a wrapper to facilitate Google Cast integration.
// To enable Chromecast:
// 1. Add 'GoogleCast' via Swift Package Manager (https://github.com/googlecast/Cast-iOS-SDK)
// 2. Uncomment the import and the code below
import GoogleCast

class ChromecastManager: NSObject, ObservableObject, GCKSessionManagerListener, GCKRemoteMediaClientListener {
    static let shared = ChromecastManager()
    
    @Published var devices: [GCKDevice] = []
    @Published var isConnected = false
    
    override init() {
        super.init()
    }
    
    func initialize() {
        print("[ChromecastManager] 🚀 Initializing Cast SDK...")
        let options = GCKCastOptions(discoveryCriteria: GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID))
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        options.suspendSessionsWhenBackgrounded = false // Allow auto-reconnection
        
        GCKCastContext.setSharedInstanceWith(options)
        
        GCKCastContext.sharedInstance().sessionManager.add(self)
        GCKCastContext.sharedInstance().discoveryManager.add(self)
        GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
        
        // Check for existing session on app launch
        if GCKCastContext.sharedInstance().sessionManager.hasConnectedCastSession() {
            print("[ChromecastManager] 🔗 Found existing connected session on launch")
            self.isConnected = true
            
            // Trigger session restoration
            if let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession {
                print("[ChromecastManager] 🔗 Restoring session for device: \(session.device.friendlyName ?? "Unknown")")
                sessionManager(GCKCastContext.sharedInstance().sessionManager, didStart: session)
            }
        } else {
            print("[ChromecastManager] ℹ️ No existing Cast session found")
        }
    }
    
    func startDiscovery() {
        GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
    }
    
    func connect(to device: GCKDevice) {
        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
    }
    
    func cast(url: URL, title: String, image: String?, isLive: Bool = false) {
        print("[ChromecastManager] ===== CAST ATTEMPT START =====")
        print("[ChromecastManager] URL: \(url.absoluteString)")
        print("[ChromecastManager] Title: \(title)")
        print("[ChromecastManager] isLive: \(isLive)")
        
        guard let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession else {
            print("[ChromecastManager] ❌ FATAL: No active Cast Session found")
            return
        }
        print("[ChromecastManager] ✅ Session exists: \(session.device.friendlyName ?? "Unknown")")
        
        guard let remoteClient = session.remoteMediaClient else {
             print("[ChromecastManager] ❌ FATAL: No RemoteMediaClient available")
             return
        }
        print("[ChromecastManager] ✅ RemoteMediaClient exists")
        
        remoteClient.add(self) // Listen for media status
        
        
        print("[ChromecastManager] Building MediaInfo...")
        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        if let image = image, let imgUrl = URL(string: image) {
            metadata.addImage(GCKImage(url: imgUrl, width: 480, height: 360))
        }
        
        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.contentID = url.absoluteString // EXPLICITLY SET CONTENT ID (Matches Web's streamSrc)
        builder.streamType = isLive ? .live : .buffered
        builder.contentType = "application/x-mpegURL"
        builder.metadata = metadata
        builder.hlsSegmentFormat = .TS // Enforce TS format like AnisFlix
        
        let mediaInfo = builder.build()
        print("[ChromecastManager] MediaInfo built - ContentID: \(mediaInfo.contentID ?? "nil")")
        print("[ChromecastManager] MediaInfo ContentType: \(mediaInfo.contentType ?? "nil")")
        print("[ChromecastManager] MediaInfo StreamType: \(mediaInfo.streamType.rawValue)")
        print("[ChromecastManager] MediaInfo HLS Format: \(mediaInfo.hlsSegmentFormat.rawValue)")
        
        // CRITICAL: Use loadOptions like AnisFlix
        let loadOptions = GCKMediaLoadOptions()
        loadOptions.autoplay = true
        
        print("[ChromecastManager] 📤 Calling loadMedia() WITH loadOptions...")
        let request = remoteClient.loadMedia(mediaInfo, with: loadOptions)
        
        print("[ChromecastManager] Request ID: \(request.requestID)")
        print("[ChromecastManager] ===== CAST ATTEMPT END =====")
    }
    
    // MARK: - Remote Media Client Listener
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didStartMediaSessionId mediaSessionId: Int) {
        print("[ChromecastManager] 🎬 Media Session Started (ID: \(mediaSessionId))")
    }
    
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didComplete loadRequest: GCKRequest) {
        print("[ChromecastManager] ✅ Load Request Completed (ID: \(loadRequest.requestID))")
    }
    
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didFailToLoadMediaWithError error: Error) {
        print("[ChromecastManager] ❌ Load Request FAILED: \(error.localizedDescription)")
        print("[ChromecastManager] Error details: \(error)")
    }
    
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        guard let status = mediaStatus else { return }
        print("[ChromecastManager] 📊 Media Status Update: playerState=\(status.playerState.rawValue), idleReason=\(status.idleReason.rawValue)")
    }
    
    // MARK: - Session Listener
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        withAnimation {
            isConnected = true
        }
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        withAnimation {
            isConnected = false
        }
    }
    
    // MARK: - Discovery Listener
    func didStartDiscovery(forDeviceCategory deviceCategory: String) {
        print("Chromecast Discovery Started")
    }
    
    func didUpdate(_ device: GCKDevice, at index: UInt, andMoveTo newIndex: UInt) {
        updateDevices()
    }
    
    func didInsert(_ device: GCKDevice, at index: UInt) {
        updateDevices()
    }
    
    func didRemove(_ device: GCKDevice, at index: UInt) {
        updateDevices()
    }

    private func updateDevices() {
        let count = GCKCastContext.sharedInstance().discoveryManager.deviceCount
        var newDevices: [GCKDevice] = []
        for i in 0..<count {
            let device = GCKCastContext.sharedInstance().discoveryManager.device(at: i)
            newDevices.append(device)
        }
        
        DispatchQueue.main.async {
            self.devices = newDevices
        }
    }
    
    func disconnect() {
        GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
    }
}

extension ChromecastManager: GCKDiscoveryManagerListener {}

// SwiftUI Representable for the Cast Button (Visual Only)
struct ChromecastButton: UIViewRepresentable {
    var tintColor: UIColor = .white
    
    func makeUIView(context: Context) -> GCKUICastButton {
        let btn = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        btn.tintColor = tintColor
        // Disable user interaction so the SwiftUI wrapper can catch the tap
        // This effectively makes it just a visual icon managed by the SDK
        btn.isUserInteractionEnabled = false 
        return btn
    }
    
    func updateUIView(_ uiView: GCKUICastButton, context: Context) {
        if uiView.tintColor != tintColor {
            uiView.tintColor = tintColor
        }
    }
}

