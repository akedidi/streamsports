import Foundation

class ProxySegmentDelegate: NSObject, URLSessionDataDelegate {
    private var onResponseReady: ((URLResponse) -> Void)?
    
    // Thread-safe buffer
    private let queue = DispatchQueue(label: "com.streamsports.segment.delegate")
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
        queue.async {
            if let completion = self.pendingReadCompletion {
                self.pendingReadCompletion = nil
                DispatchQueue.global().async { completion(data, nil) }
            } else {
                self.buffer.append(data)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async {
            self.isFinished = true
            self.responseError = error
            
            if let completion = self.pendingReadCompletion {
                self.pendingReadCompletion = nil
                let outData = self.buffer.isEmpty ? Data() : self.buffer.removeFirst()
                DispatchQueue.global().async { completion(outData, error) }
            }
        }
    }
    
    func readNextChunk(completion: @escaping (Data?, Error?) -> Void) {
        queue.async {
            if let error = self.responseError {
                completion(nil, error)
            } else if !self.buffer.isEmpty {
                let data = self.buffer.removeFirst()
                completion(data, nil)
            } else if self.isFinished {
                completion(Data(), nil) // EOF
            } else {
                self.pendingReadCompletion = completion
            }
        }
    }
}

class ProxySegmentManager {
    static let shared = ProxySegmentManager()
    
    private let queue = DispatchQueue(label: "com.streamsports.segment.manager")
    private var activeSessions: [String: ProxySegmentDelegate] = [:]
    
    private init() {}
    
    func register(task: URLSessionDataTask, urlString: String) {
        guard let delegate = task.delegate as? ProxySegmentDelegate else { return }
        queue.async {
            self.activeSessions[urlString] = delegate
        }
    }
    
    func readNextChunk(for urlString: String, completion: @escaping (Data?, Error?) -> Void) {
        queue.async {
            guard let delegate = self.activeSessions[urlString] else {
                completion(Data(), nil) // Fake EOF if not found
                return
            }
            
            delegate.readNextChunk { data, error in
                completion(data, error)
                
                // Cleanup on EOF or error
                if error != nil || (data != nil && data!.isEmpty) {
                    self.queue.async {
                        self.activeSessions.removeValue(forKey: urlString)
                    }
                }
            }
        }
    }
}
