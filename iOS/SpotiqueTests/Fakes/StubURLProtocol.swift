import Foundation

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(Data, HTTPURLResponse)] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard !Self.responses.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (data, response) = Self.responses.removeFirst()
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func enqueue(statusCode: Int, json: String, url: URL = URL(string: "http://localhost:3000/api/v1")!) {
        let data = json.data(using: .utf8)!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        responses.append((data, response))
    }

    static func enqueue(statusCode: Int, data: Data, url: URL = URL(string: "http://localhost:3000/api/v1")!) {
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        responses.append((data, response))
    }

    static func reset() {
        responses.removeAll()
    }
}
