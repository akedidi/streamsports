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
    
    @Published var isConnected = false
    
    override init() {
        super.init()
        let options = GCKCastOptions(discoveryCriteria: GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID))
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        GCKCastContext.setSharedInstanceWith(options)
        
        GCKCastContext.sharedInstance().sessionManager.add(self)
        GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
    }
    
    func startDiscovery() {
        GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
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
}

// SwiftUI Representable for the Cast Button
struct ChromecastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let btn = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        btn.tintColor = .white
        return btn
    }
    
    func updateUIView(_ uiView: GCKUICastButton, context: Context) {}
}
