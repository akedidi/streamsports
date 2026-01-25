import Foundation
import Combine
import SwiftUI

// This is a wrapper to facilitate Google Cast integration.
// To enable Chromecast:
// 1. Add 'GoogleCast' via Swift Package Manager (https://github.com/googlecast/Cast-iOS-SDK)
// 2. Uncomment the import and the code below
import GoogleCast

class ChromecastManager: NSObject, ObservableObject, GCKSessionManagerListener {
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
    }
    
    func startDiscovery() {
        GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
    }
    
    func connect(to device: GCKDevice) {
        GCKCastContext.sharedInstance().sessionManager.startSession(with: device)
    }
    
    func cast(url: URL, title: String, image: String?) {
        guard let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession else { return }
        
        let metadata = GCKMediaMetadata(metadataType: .generic)
        metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        if let image = image, let imgUrl = URL(string: image) {
            metadata.addImage(GCKImage(url: imgUrl, width: 480, height: 360))
        }
        
        let builder = GCKMediaInformationBuilder(contentURL: url)
        builder.streamType = .live
        builder.contentType = "application/x-mpegurl"
        builder.metadata = metadata
        
        let mediaInfo = builder.build()
        session.remoteMediaClient?.loadMedia(mediaInfo)
    }
    
    // MARK: - Session Listener
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        isConnected = true
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        isConnected = false
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
}

extension ChromecastManager: GCKDiscoveryManagerListener {}

// SwiftUI Representable for the Cast Button (Visual Only)
struct ChromecastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let btn = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        btn.tintColor = .white
        // Disable user interaction so the SwiftUI wrapper can catch the tap
        // This effectively makes it just a visual icon managed by the SDK
        btn.isUserInteractionEnabled = false 
        return btn
    }
    
    func updateUIView(_ uiView: GCKUICastButton, context: Context) {}
}

