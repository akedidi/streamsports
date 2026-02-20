import Foundation

class SegmentStreamDelegate: NSObject, URLSessionDataDelegate {
    private var pendingBlocks: [(Data?) -> Void] = []
    private var isFinished = false
    private var responseError: Error?
    
    // The data task backing this stream
    var dataTask: URLSessionDataTask?
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let block = pendingBlocks.first {
            pendingBlocks.removeFirst()
            block(data)
        } else {
            // Unlikely to buffer much since GCDWebServer reads sequentially
            print("⚠️ SegmentStreamDelegate: Received data without pending block")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isFinished = true
        responseError = error
        
        if let error = error {
            print("❌ SegmentStreamDelegate: Stream failed: \(error.localizedDescription)")
        }
        
        // Fulfill any waiting blocks with empty data (EOF) or error
        while let block = pendingBlocks.first {
            pendingBlocks.removeFirst()
            block(Data())
        }
    }
    
    // Interface for GCDWebServerAsyncStreamBlock
    func readNextChunk(completion: @escaping (Data?) -> Void) {
        if isFinished {
            completion(Data())
        } else {
            pendingBlocks.append(completion)
        }
    }
}
