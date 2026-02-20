import Foundation

class ProxySegmentDelegate: NSObject, URLSessionDataDelegate {
    private var onResponseReady: ((URLResponse) -> Void)?
    
    // Thread-safe buffer using NSLock instead of DispatchQueue to avoid deadlocking GCD pool
    private let lock = NSLock()
    private var buffer: [Data] = []
    private var pendingReadCompletion: ((Data?, Error?) -> Void)?
    private var isFinished = false
    private var responseError: Error?
    
    init(onResponseReady: @escaping (URLResponse) -> Void) {
        self.onResponseReady = onResponseReady
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        onResponseReady?(response)
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
        
        if let completion = self.pendingReadCompletion {
            self.pendingReadCompletion = nil
            let outData = self.buffer.isEmpty ? Data() : self.buffer.removeFirst()
            lock.unlock()
            completion(outData, error)
        } else {
            lock.unlock()
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
