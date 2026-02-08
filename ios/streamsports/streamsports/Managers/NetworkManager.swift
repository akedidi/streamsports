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
    
    func resolveStream(url: String, completion: @escaping (String?, String?, String?) -> Void) {
        // We must properly encoding the URL parameter so that & and ? are escaped.
        // .urlQueryAllowed DOES NOT escape & and ?, which breaks the backend parsing.
        
        // Use URLComponents to properly encode the query parameter
        // The backend expects 'url' to be the full target URL.
        guard var components = URLComponents(string: "\(baseURL)/stream") else {
             print("[NetworkManager] Invalid Base URL")
             completion(nil, nil, nil)
             return
        }
        
        components.queryItems = [
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "force_proxy", value: "true") // Force full proxy for iOS AVPlayer
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
                    // streamPath is like "/api/proxy?..."
                    // We need to prepend the domain if it's relative
                    if streamPath.hasPrefix("http") {
                        finalProxyUrl = streamPath
                    } else {
                        // Construct full URL using the same host as baseURL (minus /api)
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
