import Foundation
import OSLog


actor ContextServer {
    private let server = NetworkServer()
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "MCP")

    static let host = "127.0.0.1"
    static let port: UInt16 = 7345
    static let endpoint = "/mcp"

    static let instructions = """
        Scint exposes two tools: scint.domain and scint.intent. Every call supplies a domain or \
        intent selector, an action, and an arguments object. Use scint.intent with intent=search, \
        action=search and arguments.method=list or describe to discover references, content, \
        interface argument schemas, and each reference's scopes. Addresses are scint://<kind>/<id>. \
        Domain manages interfaces, materials, and structures. Intent composes, dispatches, \
        observes, and searches. Identity comes only from the SCINT_CONTEXT bearer and is verified \
        against the live composition before entering the runtime. Scopes are recomputed on every call.
        """

    static var url: URL { URL(string: "http://\(host):\(port)\(endpoint)")! }
    static var args: [String] {
        ["mcp", "add", "scint", "--url", url.absoluteString, "--bearer-token-env-var", "SCINT_CONTEXT"]
    }

    func start() async throws {
        try await server.start(port: Self.port) { [weak self] request in
            guard let self else {
                return MCPResponse.failure(nil, .unavailable("Scint server is unavailable."))
            }
            return await self.handle(request)
        }
    }

    func stop() async { server.stop() }

    func handle(_ http: HTTPRequest) async -> HTTPResponse {
        do {
            return try await route(http)
        } catch let error as MCPError {
            Self.logger.error("MCP \(http.path ?? "", privacy: .public) -> \(error.status) \(error.message, privacy: .public)")
            return MCPResponse.failure(identifier(of: http), error)
        } catch {
            return MCPResponse.failure(nil, .unavailable(String(describing: error)))
        }
    }

    private func route(_ http: HTTPRequest) async throws -> HTTPResponse {
        try accept(http)

        let request = try MCPRequest.decode(http)

        if request.method == MCPRequest.Method.initialize { return initialize(request) }

        try MCPHandshake.validate(request)

        let session = try await MCPSession.resolve(request)

        guard !request.isNotification else {
            Self.logger.notice("MCP \(request.method, privacy: .public) context \(session.context.uuidString, privacy: .public) -> 202")
            return MCPResponse.accepted()
        }

        let response = try await dispatch(request, in: session)
        Self.logger.notice("MCP \(request.method, privacy: .public) context \(session.context.uuidString, privacy: .public) -> \(response.statusCode)")
        return response
    }

    private func initialize(_ request: MCPRequest) -> HTTPResponse {
        let requested = request.parameters["protocolVersion"]?.string
        let version = MCPResponse.negotiated(requested)
        Self.logger.notice(
            "MCP initialize requested \(requested ?? "none", privacy: .public) -> \(version, privacy: .public)"
        )

        return MCPResponse.result(request.id, [
            "protocolVersion": .string(version),
            "capabilities": .object(["tools": .object(["listChanged": .bool(false)])]),
            "serverInfo": .object([
                "name": .string(MCPResponse.serverName),
                "version": .string(MCPResponse.serverVersion)
            ]),
            "instructions": .string(Self.instructions)
        ])
    }

    private func accept(_ http: HTTPRequest) throws(MCPError) {
        guard http.path == Self.endpoint else { throw MCPError.notFound("Not Found") }
        guard http.method == "POST" else {
            throw MCPError.invalidRequest("Only POST is supported.", status: 405)
        }
        guard isLoopback(http) else {
            throw MCPError.invalidRequest("Invalid Origin header.", status: 403)
        }
    }

    private func dispatch(_ request: MCPRequest, in session: MCPSession) async throws(MCPError) -> HTTPResponse {
        switch request.method {
            case MCPRequest.Method.discover:
                return MCPResponse.result(request.id, [
                    "resultType": .string("complete"),
                    "supportedVersions": .array(MCPResponse.supportedVersions.map(Property.string)),
                    "capabilities": .object(["tools": .object([:])]),
                    "instructions": .string(Self.instructions),
                    "ttlMs": .integer(0),
                    "cacheScope": .string("private")
                ])

            case MCPRequest.Method.listTools:
                return MCPResponse.result(request.id, [
                    "resultType": .string("complete"),
                    "tools": .array(session.tools.map(\.definition)),
                    "ttlMs": .integer(0),
                    "cacheScope": .string("private")
                ])

            case MCPRequest.Method.callTool:
                return await call(request, in: session)

            default:
                throw MCPError.notFound("Method not found: \(request.method)")
        }
    }

    private func call(_ request: MCPRequest, in session: MCPSession) async -> HTTPResponse {
        guard let name = request.parameters["name"]?.string else {
            return MCPResponse.failure(request.id, .invalidParameters("Tool name is required."))
        }

        let arguments: Properties
        if let value = request.parameters["arguments"] {
            guard let value = value.properties else {
                return MCPResponse.failure(request.id, .invalidParameters("Tool arguments must be an object."))
            }
            arguments = value
        } else {
            arguments = .object([String: Property]())
        }

        guard let tool = session.tool(named: name) else {
            let available = session.tools.map(\.name).sorted().joined(separator: ", ")
            return MCPResponse.failure(
                request.id,
                .invalidParameters(
                    available.isEmpty
                        ? "Unknown tool: \(name). This space exposes no tools."
                        : "Unknown tool: \(name). Available: \(available)."
                )
            )
        }

        let result = await tool.call(arguments)
        return MCPResponse.result(request.id, [
            "resultType": .string("complete"),
            "content": .array([.object([
                "type": .string("text"),
                "text": .string(result.text)
            ])]),
            "isError": .bool(result.isError)
        ])
    }

    // MARK: - Transport

    private func isLoopback(_ http: HTTPRequest) -> Bool {
        guard let origin = http.header("Origin") else { return true }
        guard let host = URL(string: origin)?.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    /// Best effort at echoing the caller's id back on a failure that happened before decoding.
    private func identifier(of http: HTTPRequest) -> Property? {
        guard let body = http.body,
              let message = try? JSONDecoder().decode(Property.self, from: body)
        else { return nil }
        return message["id"]
    }
}
