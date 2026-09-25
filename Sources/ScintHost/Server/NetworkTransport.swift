import Foundation
@preconcurrency import Network
import ScintRuntime


final class NetworkTransport: @unchecked Sendable {
    typealias Handler = @Sendable (Request) async -> Response

    private final class Ready: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Error>?

        init(_ continuation: CheckedContinuation<Void, Error>) { self.continuation = continuation }

        func resume(_ result: Result<Void, Error>) {
            lock.withLock {
                continuation?.resume(with: result)
                continuation = nil
            }
        }
    }

    struct Request: Sendable {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data?

        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        var bearer: UUID? {
            guard let parts = header("Authorization")?.split(separator: " ", maxSplits: 1),
                  parts.count == 2,
                  parts[0].caseInsensitiveCompare("Bearer") == .orderedSame
            else { return nil }
            return UUID(uuidString: String(parts[1]))
        }

        var isLoopback: Bool {
            guard let origin = header("Origin") else { return true }
            guard let host = URL(string: origin)?.host?.lowercased() else { return false }
            return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
        }
    }

    struct Response: Sendable {
        let status: Int
        var body: Data? = nil
    }

    private let port: UInt16
    private let queue = DispatchQueue(label: "com.kaechle.scint.http")
    private let lock = NSLock()
    private var listener: NWListener?

    init(port: UInt16 = ContextProtocol.port) {
        self.port = port
    }

    func start(_ handler: @escaping Handler) async throws {
        guard lock.withLock({ listener == nil }), let port = NWEndpoint.Port(rawValue: port) else { return }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global(qos: .userInitiated))
            Self.receive(connection, data: Data(), handler: handler)
        }
        lock.withLock { self.listener = listener }

        do {
            try await withCheckedThrowingContinuation { continuation in
                let ready = Ready(continuation)
                listener.stateUpdateHandler = { state in
                    switch state {
                        case .ready: ready.resume(.success(()))
                        case .failed(let error), .waiting(let error): ready.resume(.failure(error))
                        case .cancelled: ready.resume(.failure(CancellationError()))
                        default: break
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

    private static func receive(_ connection: NWConnection, data: Data, handler: @escaping Handler) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { content, _, complete, error in
            var received = data
            if let content { received.append(content) }

            if let request = request(received) {
                Task { send(await handler(request), on: connection) }
            } else if error == nil, !complete, received.count < 16 * 1_024 * 1_024 {
                receive(connection, data: received, handler: handler)
            } else {
                connection.cancel()
            }
        }
    }

    private static func request(_ data: Data) -> Request? {
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let lines = String(decoding: data[..<boundary.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        guard let line = lines.first?.split(separator: " "), line.count >= 2 else { return nil }

        let headers = lines.dropFirst().reduce(into: [String: String]()) { headers, line in
            guard let colon = line.firstIndex(of: ":") else { return }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[name] = headers[name].map { "\($0), \(value)" } ?? value
        }
        let length = headers.first { $0.key.caseInsensitiveCompare("Content-Length") == .orderedSame }
            .flatMap { Int($0.value) } ?? 0
        let start = boundary.upperBound
        guard data.count >= start + length else { return nil }

        return Request(
            method: String(line[0]),
            path: line[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? "",
            headers: headers,
            body: length == 0 ? nil : data.subdata(in: start..<(start + length))
        )
    }

    private static func send(_ response: Response, on connection: NWConnection) {
        let body = response.body ?? Data()
        var head = "HTTP/1.1 \(response.status) \(reason(response.status))\r\n"
        if !body.isEmpty { head += "Content-Type: application/json\r\n" }
        head += "Content-Length: \(body.count)\r\nConnection: close\r\n\r\n"

        var data = Data(head.utf8)
        data.append(body)
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    private static func reason(_ status: Int) -> String {
        switch status {
            case 200: "OK"
            case 202: "Accepted"
            case 403: "Forbidden"
            case 404: "Not Found"
            case 405: "Method Not Allowed"
            default: "Internal Server Error"
        }
    }
}
