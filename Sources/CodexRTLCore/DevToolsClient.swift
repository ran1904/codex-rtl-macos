import Foundation

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public final class DevToolsClient {
    public let port: Int
    private static let maximumTargetListBytes = 1_048_576
    private let redirectDelegate: NoRedirectDelegate?
    private let session: URLSession

    public init(port: Int = 9224, session: URLSession? = nil) {
        self.port = port
        if let session {
            self.redirectDelegate = nil
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 2
            configuration.timeoutIntervalForResource = 4
            configuration.waitsForConnectivity = false
            let redirectDelegate = NoRedirectDelegate()
            self.redirectDelegate = redirectDelegate
            self.session = URLSession(
                configuration: configuration,
                delegate: redirectDelegate,
                delegateQueue: nil
            )
        }
    }

    public func codexTargets() async throws -> [DevToolsTarget] {
        let endpoint = URL(string: "http://127.0.0.1:\(port)/json")!
        guard LoopbackPolicy.isAllowedHTTP(endpoint, port: port) else {
            throw CodexRTLError.invalidLoopbackURL
        }

        do {
            let (data, response) = try await boundedData(
                from: endpoint,
                maximumBytes: Self.maximumTargetListBytes
            )
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw CodexRTLError.invalidResponse
            }
            guard let finalURL = http.url, LoopbackPolicy.isAllowedHTTP(finalURL, port: port) else {
                throw CodexRTLError.invalidLoopbackURL
            }
            return try JSONDecoder().decode([DevToolsTarget].self, from: data).filter(\.isCodexRenderer)
        } catch let error as CodexRTLError {
            throw error
        } catch {
            throw CodexRTLError.devToolsUnavailable
        }
    }

    private func boundedData(from url: URL, maximumBytes: Int) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(from: url)
        if response.expectedContentLength > Int64(maximumBytes) {
            throw CodexRTLError.invalidResponse
        }

        var data = Data()
        data.reserveCapacity(
            min(maximumBytes, max(0, Int(response.expectedContentLength)))
        )
        for try await byte in bytes {
            guard data.count < maximumBytes else {
                throw CodexRTLError.invalidResponse
            }
            data.append(byte)
        }
        return (data, response)
    }

    public func evaluate(_ expression: String, in target: DevToolsTarget) async throws -> Bool {
        guard let rawURL = target.webSocketDebuggerUrl,
              let socketURL = URL(string: rawURL),
              LoopbackPolicy.isAllowedWebSocket(socketURL, port: port) else {
            throw CodexRTLError.invalidLoopbackURL
        }

        let socket = session.webSocketTask(with: socketURL)
        socket.resume()
        defer { socket.cancel(with: .normalClosure, reason: nil) }

        let request: [String: Any] = [
            "id": 1,
            "method": "Runtime.evaluate",
            "params": [
                "expression": expression,
                "awaitPromise": false,
                "returnByValue": true
            ]
        ]
        let requestData = try JSONSerialization.data(withJSONObject: request)
        guard let requestText = String(data: requestData, encoding: .utf8) else {
            throw CodexRTLError.invalidResponse
        }
        try await socket.send(.string(requestText))

        let data = try await receive(socket)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["error"] == nil,
              let outerResult = object["result"] as? [String: Any],
              outerResult["exceptionDetails"] == nil,
              let remoteObject = outerResult["result"] as? [String: Any],
              let value = remoteObject["value"] as? Bool else {
            throw CodexRTLError.rendererRejected
        }
        return value
    }

    private func receive(_ socket: URLSessionWebSocketTask) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                let message = try await socket.receive()
                switch message {
                case let .string(text):
                    return Data(text.utf8)
                case let .data(data):
                    return data
                @unknown default:
                    throw CodexRTLError.invalidResponse
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 4_000_000_000)
                throw CodexRTLError.requestTimedOut
            }

            guard let first = try await group.next() else {
                throw CodexRTLError.invalidResponse
            }
            group.cancelAll()
            return first
        }
    }
}
