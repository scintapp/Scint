import Foundation
import MCP
@preconcurrency import Network


final class NetworkServer: @unchecked Sendable {
    typealias Handler = @Sendable (HTTPRequest) async -> HTTPResponse

    private let queue = DispatchQueue(label: "com.kaechle.agency.mcp.bookmark")
    private let lock = NSLock()
    private var listener: NWListener?

    private final class Start: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Swift.Error>?

        init(_ continuation: CheckedContinuation<Void, Swift.Error>) { self.continuation = continuation }

        func resume(_ result: Result<Void, Swift.Error>) {
            lock.withLock {
                guard let continuation else { return }
                self.continuation = nil
                continuation.resume(with: result)
            }
        }
    }

    func start(port: UInt16, handler: @escaping Handler) async throws {
        guard lock.withLock({ listener == nil }) else { return }
        guard let port = NWEndpoint.Port(rawValue: port) else { throw Server.Error.invalidPort }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .init("127.0.0.1"), port: port)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { connection in Self.receive(connection, handler: handler) }
        lock.withLock { self.listener = listener }
        do {
            try await withCheckedThrowingContinuation { continuation in
                let start = Start(continuation)
                listener.stateUpdateHandler = { state in
                    switch state {
                        case .ready: start.resume(.success(()))
                        case .failed(let error): start.resume(.failure(error))
                        case .cancelled: start.resume(.failure(CancellationError()))
                        case .setup, .waiting: break
                        @unknown default: break
                    }
                }
                listener.start(queue: queue)
            }
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        lock.withLock {
            listener?.cancel()
            listener = nil
        }
    }

    private static func receive(_ connection: NWConnection, handler: @escaping Handler) {
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        receive(connection, data: Data(), handler: handler)
    }

    private static func receive(_ connection: NWConnection, data: Data, handler: @escaping Handler) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { content, _, complete, error in
            var received = data
            if let content { received.append(content) }

            if let request = request(received) {
                Task { send(await handler(request), on: connection) }
            } else if error == nil, !complete, received.count < 8_388_608 {
                receive(connection, data: received, handler: handler)
            } else {
                connection.cancel()
            }
        }
    }

    private static func request(_ data: Data) -> HTTPRequest? {
        let separator = Data([13, 10, 13, 10])
        guard let boundary = data.range(of: separator) else { return nil }
        let header = String(decoding: data[..<boundary.lowerBound], as: UTF8.self)
        let lines = header.components(separatedBy: "\r\n")
        guard let request = lines.first?.split(separator: " "), request.count >= 2 else { return nil }

        let headers = lines.dropFirst().reduce(into: [String: String]()) { values, line in
            guard let colon = line.firstIndex(of: ":") else { return }
            let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            values[name] = values[name].map { $0 + ", " + value } ?? value
        }
        let length = headers.first { $0.key.caseInsensitiveCompare("Content-Length") == .orderedSame }
            .flatMap { Int($0.value) } ?? 0
        let start = boundary.upperBound
        guard data.count >= start + length else { return nil }
        let body = length == 0 ? nil : data.subdata(in: start..<(start + length))
        let path = String(request[1]).split(separator: "?", maxSplits: 1).first.map(String.init)
        return HTTPRequest(method: String(request[0]), headers: headers, body: body, path: path)
    }

    private static func send(_ response: HTTPResponse, on connection: NWConnection) {
        let body = response.bodyData ?? Data()
        var headers = response.headers
        headers["Content-Length"] = String(body.count)
        headers["Connection"] = "close"

        let status = "HTTP/1.1 \(response.statusCode) \(reason(response.statusCode))\r\n"
        let fields = headers.map { "\($0.key): \($0.value)\r\n" }.joined()
        var data = Data((status + fields + "\r\n").utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func reason(_ status: Int) -> String {
        switch status {
            case 200: "OK"
            case 202: "Accepted"
            case 400: "Bad Request"
            case 401: "Unauthorized"
            case 403: "Forbidden"
            case 404: "Not Found"
            case 405: "Method Not Allowed"
            default: "Internal Server Error"
        }
    }
}
