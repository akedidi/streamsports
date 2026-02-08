import Foundation
import WebKit

/// WebView-based stream resolver for cdn-live.tv
/// Loads the player page in an invisible WebView and intercepts M3U8 requests
/// This ensures the token is generated for the iPhone's IP, bypassing IP binding issues
class WebViewStreamResolver: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    
    static let shared = WebViewStreamResolver()
    
    private var webView: WKWebView?
    private var completion: ((String?, String?) -> Void)?
    private var timeoutTimer: Timer?
    private let timeout: TimeInterval = 15.0
    
    /// Resolves a player URL by loading it in a WebView and intercepting M3U8 requests
    /// - Parameters:
    ///   - playerUrl: The cdn-live.tv player URL
    ///   - completion: Callback with (streamUrl, cookie) or (nil, nil) on failure
    func resolve(playerUrl: String, completion: @escaping (String?, String?) -> Void) {
        // Clean up any previous resolution
        cleanup()
        
        self.completion = completion
        
        print("[WebViewResolver] Starting resolution for: \(playerUrl)")
        
        // Create WebView configuration
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Inject JavaScript to intercept network requests
        let script = """
        (function() {
            // Intercept XMLHttpRequest
            const originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
                if (url.includes('.m3u8')) {
                    window.webkit.messageHandlers.m3u8Handler.postMessage(url);
                }
                return originalOpen.apply(this, arguments);
            };
            
            // Intercept fetch
            const originalFetch = window.fetch;
            window.fetch = function(url, options) {
                if (typeof url === 'string' && url.includes('.m3u8')) {
                    window.webkit.messageHandlers.m3u8Handler.postMessage(url);
                } else if (url instanceof Request && url.url.includes('.m3u8')) {
                    window.webkit.messageHandlers.m3u8Handler.postMessage(url.url);
                }
                return originalFetch.apply(this, arguments);
            };
            
            // Also watch for video element sources
            const observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'attributes' && mutation.attributeName === 'src') {
                        const src = mutation.target.src;
                        if (src && src.includes('.m3u8')) {
                            window.webkit.messageHandlers.m3u8Handler.postMessage(src);
                        }
                    }
                });
            });
            
            // Observe all video elements
            document.addEventListener('DOMContentLoaded', function() {
                const videos = document.getElementsByTagName('video');
                for (let video of videos) {
                    observer.observe(video, { attributes: true });
                    if (video.src && video.src.includes('.m3u8')) {
                        window.webkit.messageHandlers.m3u8Handler.postMessage(video.src);
                    }
                }
            });
        })();
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(self, name: "m3u8Handler")
        
        // Create WebView (invisible, minimal size)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 240), configuration: config)
        webView?.navigationDelegate = self
        
        // Set timeout
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            print("[WebViewResolver] ⏱️ Timeout - no M3U8 found")
            self?.finish(streamUrl: nil, cookie: nil)
        }
        
        // Load the player page
        if let url = URL(string: playerUrl) {
            let request = URLRequest(url: url)
            webView?.load(request)
        } else {
            print("[WebViewResolver] ❌ Invalid URL")
            finish(streamUrl: nil, cookie: nil)
        }
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "m3u8Handler",
              let urlString = message.body as? String else {
            return
        }
        
        print("[WebViewResolver] 🎯 Intercepted M3U8: \(urlString.prefix(80))...")
        
        // Extract cookie from WebView's cookie store
        extractCookie { [weak self] cookie in
            self?.finish(streamUrl: urlString, cookie: cookie)
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[WebViewResolver] ✅ Page loaded")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[WebViewResolver] ❌ Navigation failed: \(error.localizedDescription)")
        finish(streamUrl: nil, cookie: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[WebViewResolver] ❌ Provisional navigation failed: \(error.localizedDescription)")
        finish(streamUrl: nil, cookie: nil)
    }
    
    // MARK: - Helper Methods
    
    private func extractCookie(completion: @escaping (String?) -> Void) {
        guard let cookieStore = webView?.configuration.websiteDataStore.httpCookieStore else {
            completion(nil)
            return
        }
        
        cookieStore.getAllCookies { cookies in
            // Find PHPSESSID cookie
            if let sessionCookie = cookies.first(where: { $0.name == "PHPSESSID" }) {
                let cookieString = "\(sessionCookie.name)=\(sessionCookie.value)"
                print("[WebViewResolver] 🍪 Extracted cookie: \(cookieString)")
                completion(cookieString)
            } else {
                print("[WebViewResolver] ⚠️ No PHPSESSID cookie found")
                completion(nil)
            }
        }
    }
    
    private func finish(streamUrl: String?, cookie: String?) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        if let streamUrl = streamUrl {
            print("[WebViewResolver] ✅ Resolution successful")
        } else {
            print("[WebViewResolver] ❌ Resolution failed")
        }
        
        completion?(streamUrl, cookie)
        completion = nil
        
        // Clean up WebView after a delay (to allow any pending JS to complete)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "m3u8Handler")
        webView?.stopLoading()
        webView = nil
    }
}
