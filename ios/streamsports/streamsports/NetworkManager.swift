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
    
    func resolveStream(url: String, completion: @escaping (String?) -> Void) {
        guard let targetURL = URL(string: url) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://cdn-live.tv/", forHTTPHeaderField: "Referer")
        
        print("[NetworkManager] Resolving locally: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil, let html = String(data: data, encoding: .utf8) else {
                print("[NetworkManager] Request failed: \(error?.localizedDescription ?? "No data")")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Regex to find m3u8
            // Pattern: /[\"']([^\"']*index\.m3u8\?token=[^\"']+)[\"']/
            let pattern = "[\"']([^\"']*index\\.m3u8\\?token=[^\"']+)[\"']"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let nsString = html as NSString
                let results = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
                
                if let match = results.first, match.numberOfRanges > 1 {
                    let streamUrl = nsString.substring(with: match.range(at: 1))
                    print("[NetworkManager] Found stream: \(streamUrl)")
                    DispatchQueue.main.async { completion(streamUrl) }
                } else {
                    print("[NetworkManager] No m3u8 token found in HTML")
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("[NetworkManager] Regex error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}
