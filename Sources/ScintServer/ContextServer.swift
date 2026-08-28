import Foundation
import OSLog


actor ContextServer {
    private let runtime: Runtime
    private let http = NetworkServer()

    private static let protocolVersion = "2026-07-28"
    private static let legacyProtocolVersion = "2025-06-18"
    private static let serverName = "Scint"
    private static let serverVersion = "0.1.0"
    private static let logger = Logger(subsystem: "com.kaechle.scint", category: "MCP")
    static let host = "127.0.0.1"
    static let port: UInt16 = 7345
    static let endpoint = "/mcp"

    static var url: URL { URL(string: "http://\(host):\(port)\(endpoint)")! }
    static var args: [String] { ["mcp", "add", "Scint", "--url", url.absoluteString, "--bearer-token-env-var", "SCINT_CONTEXT"] }

    enum Error: Swift.Error, CustomStringConvertible {
        case invalidPort
        case unavailableContext

        var description: String {
            switch self {
                case .invalidPort: return "The MCP server port is invalid."
                case .unavailableContext: return "The Scint execution context is no longer active."
            }
        }
    }

    init(runtime: Runtime = .shared) { self.runtime = runtime }

    func start() async throws {
        try await http.start(port: Self.port) { [weak self] request in
            guard let self else {
                return Self.error(nil, code: -32603, message: "Scint server is unavailable.", statusCode: 500)
            }
            return await self.handle(request)
        }
    }

    func stop() async { http.stop() }

    private func handle(_ request: HTTPRequest) async -> HTTPResponse {
        guard request.path == Self.endpoint else {
            Self.logger.error("MCP \(request.method, privacy: .public) \(request.path ?? "", privacy: .public) -> 404")
            return Self.error(nil, code: -32601, message: "Not Found", statusCode: 404)
        }
        guard request.method == "POST" else {
            Self.logger.error("MCP \(request.method, privacy: .public) -> 405")
            return Self.error(nil, code: -32600, message: "Only POST is supported.", statusCode: 405)
        }
        guard Self.validOrigin(request) else {
            Self.logger.error("MCP POST rejected invalid origin -> 403")
            return Self.error(nil, code: -32600, message: "Invalid Origin header.", statusCode: 403)
        }
        guard let body = request.body else {
            return Self.error(nil, code: -32700, message: "Parse error", statusCode: 400)
        }

        let message: Property
        do {
            message = try JSONDecoder().decode(Property.self, from: body)
        } catch {
            return Self.error(nil, code: -32700, message: "Parse error", statusCode: 400)
        }
        guard case .object(let object) = message,
              object["jsonrpc"] == .string("2.0"),
              let method = object["method"]?.string
        else {
            return Self.error(nil, code: -32600, message: "Invalid Request", statusCode: 400)
        }
        let id = object["id"]
        if let id {
            guard Self.valid(id: id) else {
                return Self.error(nil, code: -32600, message: "Invalid Request", statusCode: 400)
            }
        } else if method != "notifications/initialized" {
            return Self.error(nil, code: -32600, message: "Invalid Request", statusCode: 400)
        }
        let params: Properties
        if let value = object["params"] {
            guard let value = value.properties else {
                return Self.error(id, code: -32602, message: "Request parameters must be an object.", statusCode: 400)
            }
            params = value
        } else {
            params = .object([String: Property]())
        }
        if method == "initialize" || request.header("MCP-Protocol-Version") == Self.legacyProtocolVersion {
            if let response = Self.validateLegacy(request, id: id, method: method, params: params) { return response }
        } else {
            guard let id else {
                return Self.error(nil, code: -32600, message: "Invalid Request", statusCode: 400)
            }
            if let response = Self.validate(request, id: id, method: method, params: params) { return response }
        }

        guard let context = Self.context(from: request) else {
            Self.logger.error("MCP \(method, privacy: .public) missing context -> 401")
            return Self.error(id, code: -32600, message: "Scint context is required.", statusCode: 401)
        }
        // The runtime's stores are unsynchronized and mutated by the UI on the main
        // actor. Every read here serializes onto it rather than racing the app.
        let resolved = await MainActor.run {
            runtime.context().first(where: { $0.space.contextId == context })
        }
        guard let composition = resolved,
              composition.space.type == Space.self,
              composition.state == .active || composition.state == .working
        else {
            Self.logger.error("MCP \(method, privacy: .public) context \(context.uuidString, privacy: .public) unavailable -> 403")
            return Self.error(id, code: -32600, message: Error.unavailableContext.description, statusCode: 403)
        }

        if method == "notifications/initialized" {
            Self.logger.info("MCP \(method, privacy: .public) context \(context.uuidString, privacy: .public) -> 202")
            return HTTPResponse(statusCode: 202, headers: [:], bodyData: nil)
        }
        guard let id else {
            return Self.error(nil, code: -32600, message: "Invalid Request", statusCode: 400)
        }
        let response: HTTPResponse

        switch method {
            case "initialize": response = Self.initialize(id)
            case "server/discover": response = Self.discover(id)
            case "tools/list": response = await Self.listTools(id, in: composition.space)
            case "tools/call": response = await Self.callTool(id, params: params, in: composition.space)
            default: response = Self.error(id, code: -32601, message: "Method not found: \(method)", statusCode: 404)
        }
        Self.logger.info("MCP \(method, privacy: .public) context \(context.uuidString, privacy: .public) -> \(response.statusCode)")
        return response
    }

    static func initialize(_ id: Property) -> HTTPResponse {
        .json(.object([
            "jsonrpc": .string("2.0"),
            "id": id,
            "result": .object([
                "protocolVersion": .string(legacyProtocolVersion),
                "capabilities": .object(["tools": .object(["listChanged": .bool(false)])]),
                "serverInfo": .object([
                    "name": .string(serverName),
                    "version": .string(serverVersion)
                ]),
                "instructions": .string("Use the tools attached to the active Scint context.")
            ])
        ]))
    }

    static func discover(_ id: Property) -> HTTPResponse {
        result(id, [
            "resultType": .string("complete"),
            "supportedVersions": .array([.string(protocolVersion)]),
            "capabilities": .object(["tools": .object([:])]),
            "instructions": .string("Use the tools attached to the active Scint context."),
            "ttlMs": .integer(0),
            "cacheScope": .string("private")
        ])
    }

    static func listTools(_ id: Property, in origin: Reference) async -> HTTPResponse {
        let tools: [Property] = await MainActor.run {
            ServerTool.all(in: origin).map(\.definition) + ContentTool.all(in: origin).map(\.definition)
        }
        return result(id, [
            "resultType": .string("complete"),
            "tools": .array(tools),
            "ttlMs": .integer(0),
            "cacheScope": .string("private")
        ])
    }

    static func callTool(_ id: Property, params: Properties, in origin: Reference) async -> HTTPResponse {
        guard let name = params["name"]?.string else {
            return error(id, code: -32602, message: "Tool name is required.")
        }
        let arguments: Properties
        if let value = params["arguments"] {
            guard let value = value.properties else {
                return error(id, code: -32602, message: "Tool arguments must be an object.")
            }
            arguments = value
        } else {
            arguments = .object([String: Property]())
        }
        // Resolution touches the runtime; the interface path then leaves the main
        // actor before awaiting a process, so a long run never blocks the UI.
        let found = await MainActor.run {
            (interface: ServerTool.find(name, in: origin), content: ContentTool.find(name, in: origin))
        }

        let invocation: ServerTool.Invocation
        if let tool = found.interface {
            invocation = await tool.call(arguments)
        } else if let tool = found.content {
            invocation = await MainActor.run { tool.call(arguments) }
        } else {
            return error(id, code: -32602, message: "Unknown tool: \(name)")
        }
        return result(id, [
            "resultType": .string("complete"),
            "content": .array([.object([
                "type": .string("text"),
                "text": .string(invocation.text)
            ])]),
            "isError": .bool(invocation.isError)
        ])
    }

    static func validateLegacy(_ request: HTTPRequest, id: Property?, method: String, params: Properties) -> HTTPResponse? {
        if method == "initialize" {
            guard let id,
                  params["protocolVersion"]?.string == legacyProtocolVersion,
                  params["capabilities"]?.object != nil,
                  let clientInfo = params["clientInfo"], validImplementation(clientInfo)
            else {
                return error(id, code: -32602, message: "Unsupported MCP initialization request.", statusCode: 400)
            }
            return nil
        }
        guard request.header("MCP-Protocol-Version") == legacyProtocolVersion else {
            return error(id, code: -32022, message: "Unsupported or missing MCP protocol version.", statusCode: 400)
        }
        return nil
    }

    static func validate(_ request: HTTPRequest, id: Property, method: String, params: Properties) -> HTTPResponse? {
        guard let meta = params["_meta"]?.object,
              let requestedVersion = meta["io.modelcontextprotocol/protocolVersion"]?.string,
              meta["io.modelcontextprotocol/clientCapabilities"]?.object != nil
        else {
            return error(id, code: -32602, message: "Per-request MCP metadata is required.", statusCode: 400)
        }
        if let clientInfo = meta["io.modelcontextprotocol/clientInfo"], !validImplementation(clientInfo) {
            return error(id, code: -32602, message: "Client information is invalid.", statusCode: 400)
        }
        guard request.header("MCP-Protocol-Version") == requestedVersion else {
            return error(id, code: -32020, message: "Header mismatch: MCP-Protocol-Version does not match the request body.", statusCode: 400)
        }
        guard requestedVersion == protocolVersion else {
            return error(
                id,
                code: -32022,
                message: "Unsupported protocol version: \(requestedVersion)",
                statusCode: 400,
                data: .object([
                    "requested": .string(requestedVersion),
                    "supported": .array([.string(protocolVersion)])
                ])
            )
        }
        // These headers mirror the body for clients that send them. Absence is not a
        // mismatch — no shipping client emits them yet — but disagreement still is.
        if let header = request.header("Mcp-Method"), header != method {
            return error(id, code: -32020, message: "Header mismatch: Mcp-Method does not match the request body.", statusCode: 400)
        }
        if method == "tools/call",
           let header = request.header("Mcp-Name").flatMap(decodedHeader),
           header != params["name"]?.string {
            return error(id, code: -32020, message: "Header mismatch: Mcp-Name does not match the request body.", statusCode: 400)
        }
        return nil
    }

    static func result(_ id: Property, _ result: [String: Property]) -> HTTPResponse {
        var result = result
        result["_meta"] = serverMeta
        return .json(.object([
            "jsonrpc": .string("2.0"),
            "id": id,
            "result": .object(result)
        ]))
    }

    static func error(_ id: Property?, code: Int, message: String, statusCode: Int = 200, data: Property? = nil) -> HTTPResponse {
        var error: [String: Property] = [
            "code": .integer(code),
            "message": .string(message)
        ]
        if let data { error["data"] = data }
        return .json(.object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "error": .object(error)
        ]), statusCode: statusCode)
    }

    static var serverMeta: Property {
        .object([
            "io.modelcontextprotocol/serverInfo": .object([
                "name": .string(serverName),
                "version": .string(serverVersion)
            ])
        ])
    }

    static func context(from request: HTTPRequest) -> ContextId? {
        guard let authorization = request.header("Authorization") else { return nil }
        let parts = authorization.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, String(parts[0]).caseInsensitiveCompare("Bearer") == .orderedSame else { return nil }
        return UUID(uuidString: String(parts[1]))
    }

    static func valid(id: Property) -> Bool {
        switch id {
            case .integer, .decimal, .string: true
            default: false
        }
    }

    static func validImplementation(_ value: Property) -> Bool {
        guard let value = value.object else { return false }
        return value["name"]?.string != nil && value["version"]?.string != nil
    }

    static func validOrigin(_ request: HTTPRequest) -> Bool {
        guard let origin = request.header("Origin") else { return true }
        guard let host = URL(string: origin)?.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }

    static func decodedHeader(_ value: String) -> String? {
        let prefix = "=?base64?"
        guard value.hasPrefix(prefix), value.hasSuffix("?=") else { return value }
        let encoded = String(value.dropFirst(prefix.count).dropLast(2))
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
