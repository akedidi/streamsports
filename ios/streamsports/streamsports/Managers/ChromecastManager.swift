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
        let options = GCKCastOptions(discoveryCriteria: GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID))
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        GCKCastContext.setSharedInstanceWith(options)
        
        GCKCastContext.sharedInstance().sessionManager.add(self)
        GCKCastContext.sharedInstance().discoveryManager.add(self)
        GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
        
        // Restore State
        if GCKCastContext.sharedInstance().sessionManager.hasConnectedCastSession() {
            self.isConnected = true
        }
    }
    
    func startDiscovery() {
        GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
    }
    
    func connect(to device: GCKDevice) {
        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
    }
    
    func cast(url: URL, title: String, image: String?) {
        guard let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession else {
            print("[ChromecastManager] Error: No active Cast Session found when trying to cast.")
            return
        }
        
        guard let remoteClient = session.remoteMediaClient else {
             print("[ChromecastManager] Error: No RemoteMediaClient available.")
             return
        }
        
        remoteClient.add(self) // Listen for media status
        
        print("[ChromecastManager] Building MediaInfo for URL: \(url.absoluteString)")
        let metadata = GCKMediaMetadata(metadataType: .generic)
        metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        if let image = image, let imgUrl = URL(string: image) {
            metadata.addImage(GCKImage(url: imgUrl, width: 480, height: 360))
        }
        
        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.streamType = .buffered // Match Web default
        builder.contentType = "application/x-mpegURL" // Web uses this, iOS should too for consistency
        builder.metadata = metadata
        
        let mediaInfo = builder.build()
        
        let requestOptions = GCKMediaLoadOptions()
        requestOptions.autoplay = true
        
        print("[ChromecastManager] Sending loadMedia request...")
        remoteClient.loadMedia(mediaInfo, with: requestOptions)
    }
    
    // MARK: - Remote Media Client Listener
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didStartMediaSessionId mediaSessionId: Int) {
        print("[ChromecastManager] Media Session Started (ID: \(mediaSessionId))")
    }
    
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didComplete loadRequest: GCKRequest) {
        print("[ChromecastManager] Load Request Completed Successfully")
    }
    
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didFailToLoadMediaWithError error: Error) {
        print("[ChromecastManager] Load Request FAILED: \(error.localizedDescription)")
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

