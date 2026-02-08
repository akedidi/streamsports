import Foundation
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    // Using the Vercel deployment as the API source
    private let baseURL = "https://streamsports-wine.vercel.app/api"
    
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
    func resolveStream(url: String, completion: @escaping (String?, String?, String?) -> Void) {
        // Check if this is a cdn-live.tv stream that we can resolve directly
        if url.contains("cdn-live.tv") {
            print("[NetworkManager] Using DIRECT resolution for cdn-live.tv")
            resolveDirectly(url: url, completion: completion)
        } else {
            print("[NetworkManager] Using PROXY resolution for non-cdn-live stream")
            resolveViaProxy(url: url, completion: completion)
        }
    }
    
    /// Resolves a cdn-live.tv stream using hybrid WebView + Proxy approach
    /// 1. WebView resolves the player page → gets M3U8 URL with token bound to iPhone IP
    /// 2. Proxy fetches the resolved URL directly via /api/proxy → bypasses SSL/auth issues
    /// 3. AVPlayer plays via proxy → stable playback
    private func resolveDirectly(url: String, completion: @escaping (String?, String?, String?) -> Void) {
        WebViewStreamResolver.shared.resolve(playerUrl: url) { streamUrl, cookie in
            if let streamUrl = streamUrl {
                print("[NetworkManager] WebView resolution SUCCESS: \(streamUrl.prefix(80))...")
                print("[NetworkManager] Using HYBRID approach: proxying resolved URL for stable playback")
                
                // HYBRID APPROACH: Build /api/proxy URL with proper encoding
                // The server requires: url, referer, cookie parameters
                // OPTIMIZATION: Try force_proxy=false to let AVPlayer fetch segments directly (saves bandwidth)
                // ATS Exceptions added to Info.plist should now allow direct HTTPS connections.
                guard var components = URLComponents(string: "\(self.baseURL)/proxy") else {
                    print("[NetworkManager] Failed to create URLComponents")
                    completion(nil, nil, nil)
                    return
                }
                
                components.queryItems = [
                    URLQueryItem(name: "url", value: streamUrl),
                    URLQueryItem(name: "referer", value: "https://cdn-live.tv/"),
                    // REVERTED: Direct fetch failed with SSL error -12939 despite ATS.
                    // Must use proxy (now optimized with pipe/stream) for all segments.
                    URLQueryItem(name: "force_proxy", value: "true") 
                ]
                // Add cookie if available
                if let cookie = cookie {
                    components.queryItems?.append(URLQueryItem(name: "cookie", value: cookie))
                    print("[NetworkManager] Including cookie in proxy request")
                }
                
                // (force_proxy is already set above)
                
                guard let proxyUrl = components.url else {
                    print("[NetworkManager] Failed to build proxy URL")
                    completion(nil, nil, nil)
                    return
                }
                
                let proxyUrlString = proxyUrl.absoluteString
                print("[NetworkManager] Proxy URL: \(proxyUrlString.prefix(120))...")
                
                DispatchQueue.main.async {
                    // Return proxy URL for playback
                    completion(proxyUrlString, streamUrl, cookie)
                }
            } else {
                print("[NetworkManager] WebView resolution FAILED, falling back to full proxy")
                // Fall back to full proxy resolution of original player URL
                self.resolveViaProxy(url: url, completion: completion)
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
                        let host = "https://streamsports-wine.vercel.app"
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

