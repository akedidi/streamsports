import Foundation

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
        guard let encodedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let apiURL = URL(string: "\(baseURL)/stream?url=\(encodedUrl)") else { return }
        
        URLSession.shared.dataTask(with: apiURL) { data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                let response = try JSONDecoder().decode(StreamResponse.self, from: data)
                
                if let streamPath = response.streamUrl {
                    // streamPath is like "/api/proxy?..."
                    // We need to prepend the domain if it's relative
                    if streamPath.hasPrefix("http") {
                        DispatchQueue.main.async { completion(streamPath) }
                    } else {
                        // Construct full URL using the same host as baseURL (minus /api)
                        let host = "https://streamsports-wine.vercel.app"
                        DispatchQueue.main.async { completion("\(host)\(streamPath)") }
                    }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("Decoding error (stream): \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}
