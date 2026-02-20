import Foundation

class ProxySegmentDelegate: NSObject, URLSessionDataDelegate {
    private var onResponseReady: ((URLResponse?, Error?) -> Void)?
    
    // Thread-safe buffer using NSLock instead of DispatchQueue to avoid deadlocking GCD pool
    private let lock = NSLock()
    private var buffer: [Data] = []
    private var pendingReadCompletion: ((Data?, Error?) -> Void)?
    private var isFinished = false
    private var responseError: Error?
    private var responseHandled = false
    
    init(onResponseReady: @escaping (URLResponse?, Error?) -> Void) {
        self.onResponseReady = onResponseReady
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        lock.lock()
        if !responseHandled {
            responseHandled = true
            lock.unlock()
            
            if let httpRes = response as? HTTPURLResponse {
                let status = httpRes.statusCode
                if status != 200 {
                    print("🚨 [ProxySegmentManager] UPSTREAM ERROR \(status) for \(response.url?.absoluteString ?? "unknown")")
                } else {
                    print("⬇️ [ProxySegmentManager] Segment START 200 OK: \(response.url?.lastPathComponent ?? "") - Length: \(response.expectedContentLength)")
                }
            }
            onResponseReady?(response, nil)
        } else {
            lock.unlock()
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        if let completion = self.pendingReadCompletion {
            self.pendingReadCompletion = nil
            lock.unlock()
            completion(data, nil)
        } else {
            self.buffer.append(data)
            lock.unlock()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        self.isFinished = true
        self.responseError = error
        
        let needsResponseCall = !self.responseHandled
        if needsResponseCall {
            self.responseHandled = true
        }
        
        if let completion = self.pendingReadCompletion {
            self.pendingReadCompletion = nil
            let outData = self.buffer.isEmpty ? Data() : self.buffer.removeFirst()
            lock.unlock()
            
            // Deliver completion safely
            completion(outData, error)
        } else {
            lock.unlock()
        }
        
        if needsResponseCall {
            print("🚨 [ProxySegmentManager] UPSTREAM HARD ERROR: \(error?.localizedDescription ?? "Unknown")")
            onResponseReady?(nil, error)
        }
    }
    
    func readNextChunk(completion: @escaping (Data?, Error?) -> Void) {
        lock.lock()
        if let error = self.responseError {
            lock.unlock()
            completion(nil, error)
        } else if !self.buffer.isEmpty {
            let data = self.buffer.removeFirst()
            lock.unlock()
            completion(data, nil)
        } else if self.isFinished {
            lock.unlock()
            completion(Data(), nil) // EOF
        } else {
            self.pendingReadCompletion = completion
            lock.unlock()
        }
    }
}

class ProxySegmentManager {
    static let shared = ProxySegmentManager()
    
    private let lock = NSLock()
    private var activeSessions: [String: ProxySegmentDelegate] = [:]
    
    private init() {}
    
    func register(task: URLSessionDataTask, urlString: String) {
        guard let delegate = task.delegate as? ProxySegmentDelegate else { return }
        lock.lock()
        self.activeSessions[urlString] = delegate
        lock.unlock()
    }
    
    func readNextChunk(for urlString: String, completion: @escaping (Data?, Error?) -> Void) {
        lock.lock()
        guard let delegate = self.activeSessions[urlString] else {
            lock.unlock()
            completion(Data(), nil) // Fake EOF if not found
            return
        }
        lock.unlock()
        
        delegate.readNextChunk { [weak self] data, error in
            completion(data, error)
            
            // Cleanup on EOF or error
            if error != nil || (data != nil && data!.isEmpty) {
                self?.lock.lock()
                self?.activeSessions.removeValue(forKey: urlString)
                self?.lock.unlock()
            }
        }
    }
}
