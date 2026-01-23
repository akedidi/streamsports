import Foundation
import Combine
import SwiftUI

// This is a wrapper to facilitate Google Cast integration.
// To enable Chromecast:
// 1. Add 'GoogleCast' via Swift Package Manager (https://github.com/googlecast/Cast-iOS-SDK)
// 2. Uncomment the import and the code below
// import GoogleCast

class ChromecastManager: NSObject, ObservableObject {
    static let shared = ChromecastManager()
    
    @Published var isConnected = false
    
    override init() {
        super.init()
        // GCKCastContext.sharedInstance().sessionManager.add(self)
    }
    
    func startDiscovery() {
        // GCKCastContext.sharedInstance().discoveryManager.startDiscovery()
    }
    
    func cast(url: URL, title: String, image: String?) {
        // guard let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession else { return }
        // let mediaInfo = GCKMediaInformation(contentID: url.absoluteString, streamType: .live, contentType: "application/x-mpegurl", metadata: nil, streamDuration: 0, mediaTracks: nil, textTrackStyle: nil, customData: nil)
        // session.remoteMediaClient?.loadMedia(mediaInfo)
    }
}

// SwiftUI Representable for the Cast Button
struct ChromecastButton: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        // let btn = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        // return btn
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "tv"), for: .normal)
        btn.tintColor = .white
        return btn
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
