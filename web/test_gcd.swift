import Foundation
import GCDWebServer

let server = GCDWebServer()
server.addHandler(forMethod: "GET", path: "/test", request: GCDWebServerRequest.self) { request, completion in
    completion(GCDWebServerDataResponse(text: "Hello"))
}
