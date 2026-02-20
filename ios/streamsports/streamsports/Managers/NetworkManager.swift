import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // Using the Vercel deployment as the API source
    private let baseURL = "https://streamsports-proxy-718568928645.us-central1.run.app/api"
    
    func fetchChannels(completion: @escaping ([SportsChannel]) -> Void) {
        guard let url = URL(string: "\(baseURL)/channels") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Error fetching channels: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(response.channels ?? [])
                }
            } catch {
                print("Decoding error (channels): \(error)")
            }
        }.resume()
    }
    
    func fetchEvents(completion: @escaping ([SportsChannel]) -> Void) {
        guard let url = URL(string: "\(baseURL)/events?sport=all") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Error fetching events: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ChannelResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(response.events ?? [])
                }
            } catch {
                print("Decoding error (events): \(error)")
            }
        }.resume()
    }
    
    func fetchEPG(completion: @escaping (EPGResponse?) -> Void) {
        guard let url = URL(string: "https://kuzwbdweiphaouenogef.supabase.co/functions/v1/epg-data?v=v12") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Error fetching EPG: \(error?.localizedDescription ?? "Unknown")")
                completion(nil)
                return
            }
            
            do {
                let response = try JSONDecoder().decode(EPGResponse.self, from: data)
                DispatchQueue.main.async { completion(response) }
            } catch {
                print("Decoding error (EPG): \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    /// Resolves a stream URL for playback
    /// For cdn-live.tv streams, uses direct resolution on-device to avoid IP binding issues
    /// For other streams, falls back to the backend proxy
    /// - Parameters:
    ///   - url: The channel URL
    ///   - completion: Callback with (proxyUrl, rawUrl, cookie, userAgent)
    func resolveStream(url: String, completion: @escaping (String?, String?, String?, String?) -> Void) {
        // Check if this is a cdn-live.tv stream that we can resolve directly
        if url.contains("cdn-live.tv") {
            print("[NetworkManager] Using DIRECT resolution for cdn-live.tv")
            resolveDirectly(url: url, completion: completion)
        } else {
            print("[NetworkManager] Using PROXY resolution for non-cdn-live stream")
            resolveViaProxy(url: url) { proxy, raw, cookie in
                completion(proxy, raw, cookie, nil)
            }
        }
    }
    
    /// Resolves a cdn-live.tv stream using direct resolution
    /// 1. WebView resolves the player page → gets M3U8 URL with IP-bound token
    /// 2. Returns URL directly to PlayerManager for native playback (NO local proxy)
    ///
    /// WHY no local proxy: token is IP/session-bound to the WebView.
    /// URLSession (from LocalProxyServer) uses a different socket → 401.
    /// Tests confirmed: segments accessible without any headers/cookies.
    private func resolveDirectly(url: String, completion: @escaping (String?, String?, String?, String?) -> Void) {
        WebViewStreamResolver.shared.resolve(playerUrl: url) { streamUrl, cookie, userAgent in
            if let streamUrl = streamUrl {
                print("[NetworkManager] WebView resolution SUCCESS: \(streamUrl.prefix(80))...")
                print("[NetworkManager] Playing DIRECTLY (no local proxy needed — token in URL)")
                
                DispatchQueue.main.async {
                    // Pass nil for proxyUrl, streamUrl for rawUrl, cookie for cookie, and userAgent
                    completion(nil, streamUrl, cookie, userAgent)
                }
            } else {
                print("[NetworkManager] WebView resolution FAILED, falling back to backend proxy")
                self.resolveViaProxy(url: url) { proxyUrl, rawUrl, cookie in
                    completion(proxyUrl, rawUrl, cookie, nil)
                }
            }
        }
    }
    
    /// Resolves a stream via the backend proxy
    /// Can accept either a player URL or a resolved M3U8 URL
    private func resolveViaProxy(url: String, cookie: String? = nil, completion: @escaping (String?, String?, String?) -> Void) {
        guard var components = URLComponents(string: "\(baseURL)/stream") else {
             print("[NetworkManager] Invalid Base URL")
             completion(nil, nil, nil)
             return
        }
        
        components.queryItems = [
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "force_proxy", value: "true")
        ]
        
        guard let apiURL = components.url else {
            print("[NetworkManager] Failed to construct URL components for: \(url)")
            completion(nil, nil, nil)
            return
        }
        
        print("[NetworkManager] Resolving via Backend: \(apiURL)")
        URLSession.shared.dataTask(with: apiURL) { data, _, error in
            guard let data = data, error == nil else {
                print("[NetworkManager] Request error: \(error?.localizedDescription ?? "empty")")
                completion(nil, nil, nil)
                return
            }
            
            if let str = String(data: data, encoding: .utf8) {
                print("[NetworkManager] Response: \(str)")
            }
            
            do {
                let response = try JSONDecoder().decode(StreamResponse.self, from: data)
                
                let rawUrl = response.rawUrl
                let cookie = response.cookie
                var finalProxyUrl: String? = nil
                
                if let streamPath = response.streamUrl {
                    print("[NetworkManager] Found path: \(streamPath)")
                    if streamPath.hasPrefix("http") {
                        finalProxyUrl = streamPath
                    } else {
                        let host = "https://streamsports-proxy-718568928645.us-central1.run.app"
                        finalProxyUrl = "\(host)\(streamPath)"
                    }
                } else {
                    print("[NetworkManager] No streamUrl in response")
                }
                
                DispatchQueue.main.async { completion(finalProxyUrl, rawUrl, cookie) }
                
            } catch {
                print("[NetworkManager] Decoding error (stream): \(error)")
                DispatchQueue.main.async { completion(nil, nil, nil) }
            }
        }.resume()
    }
}

