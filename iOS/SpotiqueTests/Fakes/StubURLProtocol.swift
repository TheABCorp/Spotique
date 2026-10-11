import Foundation
import Synchronization
import Testing

/// Serves queued responses to any `URLSession` built with
/// `TestHelpers.stubSession()`, and records the last request it received.
/// The queue is shared, so suites using it are nested under `NetworkTests`,
/// which runs them serially.
final class StubURLProtocol: URLProtocol {
    private static let responses = Mutex<[(Data, Int)]>([])
    private static let lastRequestStorage = Mutex<URLRequest?>(nil)

    static var lastRequest: URLRequest? {
        lastRequestStorage.withLock { $0 }
    }

    static func enqueue(statusCode: Int, json: String) {
        enqueue(statusCode: statusCode, data: Data(json.utf8))
    }

    static func enqueue(statusCode: Int, data: Data) {
        responses.withLock { $0.append((data, statusCode)) }
    }

    static func reset() {
        responses.withLock { $0.removeAll() }
        lastRequestStorage.withLock { $0 = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        captured.httpBody = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        Self.lastRequestStorage.withLock { $0 = captured }

        let next = Self.responses.withLock { $0.isEmpty ? nil : $0.removeFirst() }
        guard let (data, statusCode) = next,
              let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

/// Parent suite for tests that use `StubURLProtocol`'s shared queue.
@Suite(.serialized) struct NetworkTests {}
