import Foundation
import AVFoundation

/// Custom AVAssetResourceLoader pour streams cdn-live.tv
/// Ne gère QUE la requête du manifest M3U8 (pour ajouter User-Agent/Referer/Origin).
/// Les segments MPEG-TS gardent leurs URLs https:// originales → AVPlayer les charge directement.
///
/// Pourquoi pas de réécriture de segments :
/// 1. Token dans l'URL de chaque segment → pas de headers requis (confirmé par tests Node.js)
/// 2. Le custom scheme cdnlive-https:// dans le manifest bloque HLS-FASB Apple (-15514)
class HLSResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    
    /// Scheme custom pour les URLs M3U8 → force le passage par notre loader
    static let customScheme = "cdnlive-https"
    
    private let userAgent: String
    private let referer = "https://cdn-live.tv/"
    private let origin = "https://cdn-live.tv"
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    
    init(userAgent: String) {
        self.userAgent = userAgent
    }
    
    /// Convertit une URL https:// en cdnlive-https:// pour forcer le passage par notre loader
    static func makeCustomURL(from originalURL: URL) -> URL? {
        var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)
        components?.scheme = customScheme
        return components?.url
    }
    
    /// Restaure l'URL https:// depuis cdnlive-https://
    private func originalURL(from request: AVAssetResourceLoadingRequest) -> URL? {
        guard var components = URLComponents(url: request.request.url!, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "https"
        return components.url
    }
    
    // MARK: - AVAssetResourceLoaderDelegate
    
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let url = originalURL(from: loadingRequest) else {
            loadingRequest.finishLoading(with: NSError(domain: "HLSLoader", code: -1))
            return false
        }
        
        print("[HLSLoader] Fetching manifest: \(url.lastPathComponent)")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        urlRequest.setValue(referer, forHTTPHeaderField: "Referer")
        urlRequest.setValue(origin, forHTTPHeaderField: "Origin")
        urlRequest.setValue("*/*", forHTTPHeaderField: "Accept")
        urlRequest.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("[HLSLoader] ❌ Error: \(error.localizedDescription)")
                loadingRequest.finishLoading(with: error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                loadingRequest.finishLoading(with: NSError(domain: "HLSLoader", code: -2))
                return
            }
            
            print("[HLSLoader] \(httpResponse.statusCode) for \(url.lastPathComponent)")
            
            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                print("[HLSLoader] ❌ HTTP \(httpResponse.statusCode)")
                let err = NSError(domain: "HLSLoader", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                loadingRequest.finishLoading(with: err)
                return
            }
            
            // Set content type using UTI (not MIME type — AVFoundation requires UTI)
            if let contentInfoRequest = loadingRequest.contentInformationRequest {
                contentInfoRequest.contentType = "public.m3u-playlist"
                // Do NOT set contentLength for live playlists (they refresh every ~6s)
                contentInfoRequest.isByteRangeAccessSupported = false
            }
            
            // Return ORIGINAL manifest data unchanged
            // Segments keep their original https:// URLs with tokens → AVPlayer fetches directly
            loadingRequest.dataRequest?.respond(with: data)
            loadingRequest.finishLoading()
        }
        task.resume()
        return true
    }
}
