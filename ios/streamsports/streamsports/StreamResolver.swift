import Foundation
import WebKit

class StreamResolver: NSObject, WKNavigationDelegate {
    static let shared = StreamResolver()
    
    private var webView: WKWebView?
    private var completion: ((String?) -> Void)?
    private var timer: Timer?
    
    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Use default storage for cookies
        config.applicationNameForUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView?.navigationDelegate = self
    }
    
    func resolve(url: String, completion: @escaping (String?) -> Void) {
        guard let targetURL = URL(string: url) else {
            completion(nil)
            return
        }
        
        print("[StreamResolver] Starting resolution via WebView for: \(url)")
        self.completion = completion
        
        DispatchQueue.main.async {
            // Load request
            var req = URLRequest(url: targetURL)
            req.setValue("https://cdn-live.tv/", forHTTPHeaderField: "Referer")
            self.webView?.load(req)
            
            // Timeout safety
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
                print("[StreamResolver] Timeout reached")
                self?.finish(with: nil)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[StreamResolver] Page loaded, extracting HTML...")
        
        // Wait a small moment for JS to potentially execute/redirect if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] (result, error) in
                guard let html = result as? String else {
                    print("[StreamResolver] Failed to get HTML: \(String(describing: error))")
                    self?.finish(with: nil)
                    return
                }
                
                // Parse Regex
                // Pattern matches: "url": "..." OR index.m3u8?token=...
                // The pattern used in client: /[\"']([^\"']*index\.m3u8\?token=[^\"']+)[\"']/
                let pattern = "[\"']([^\"']*index\\.m3u8\\?token=[^\"']+)[\"']"
                
                // Also try finding it in a raw console log or variable if the simple regex fails
                // But let's try the regex first
                
                let range = NSRange(location: 0, length: html.utf16.count)
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: html, options: [], range: range),
                   let r = Range(match.range(at: 1), in: html) {
                    
                    let streamUrl = String(html[r])
                    print("[StreamResolver] FOUND TOKEN via WebView: \(streamUrl)")
                    self?.finish(with: streamUrl)
                } else {
                    print("[StreamResolver] No m3u8 token found in WebView HTML.")
                    // print("HTML Dump: \(html.prefix(500))...") 
                    self?.finish(with: nil)
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[StreamResolver] Navigation failed: \(error)")
        finish(with: nil)
    }
    
    private func finish(with url: String?) {
        timer?.invalidate()
        timer = nil
        // self.webView?.stopLoading() // Keep it alive for next request? Reseting is better?
        
        if let c = completion {
            DispatchQueue.main.async {
                c(url)
            }
        }
        completion = nil
    }
}
