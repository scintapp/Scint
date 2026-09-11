import Foundation


enum MCPResponse {
    static let serverName = "scint"
    static let serverVersion = "0.1.0"
    static let protocolVersion = "2026-07-28"

    static let supportedVersions = ["2024-11-05", "2025-03-26", "2025-06-18", protocolVersion]

    static func negotiated(_ requested: String?) -> String {
        guard let requested, supportedVersions.contains(requested) else { return protocolVersion }
        return requested
    }

    static func result(_ id: Property?, _ values: [String: Property]) -> HTTPResponse {
        var values = values
        values["_meta"] = meta
        return .json(.object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "result": .object(values)
        ]))
    }

    static func failure(_ id: Property?, _ error: MCPError) -> HTTPResponse {
        var body: [String: Property] = [
            "code": .integer(error.code),
            "message": .string(error.message)
        ]
        if let data = error.data { body["data"] = data }
        return .json(.object([
            "jsonrpc": .string("2.0"),
            "id": id ?? .null,
            "error": .object(body)
        ]), statusCode: error.status)
    }

    static func accepted() -> HTTPResponse { HTTPResponse(statusCode: 202, headers: [:], bodyData: nil) }

    static var meta: Property {
        .object([
            "io.modelcontextprotocol/serverInfo": .object([
                "name": .string(serverName),
                "version": .string(serverVersion)
            ])
        ])
    }
}

struct MCPRequest {
    let id: Property?
    let method: String
    let parameters: Properties
    let http: HTTPRequest
    var isNotification: Bool { id == nil }

    static func decode(_ http: HTTPRequest) throws(MCPError) -> Self {
        guard let body = http.body else { throw MCPError.parse() }
        guard let message = try? JSONDecoder().decode(Property.self, from: body),
              case .object(let object) = message,
              object["jsonrpc"] == .string("2.0"),
              let method = object["method"]?.string
        else { throw MCPError.invalidRequest() }

        let id = object["id"]
        if let id {
            guard isValid(id: id) else { throw MCPError.invalidRequest() }
        } else if method != Method.initialized {
            throw MCPError.invalidRequest()
        }

        let parameters: Properties
        if let value = object["params"] {
            guard let value = value.properties else {
                throw MCPError.invalidParameters("Request parameters must be an object.", status: 400)
            }
            parameters = value
        } else {
            parameters = .object([String: Property]())
        }

        return Self(id: id, method: method, parameters: parameters, http: http)
    }

    private static func isValid(id: Property) -> Bool {
        switch id {
            case .integer, .decimal, .string: true
            default: false
        }
    }

    enum Method {
        static let initialize = "initialize"
        static let discover = "server/discover"
        static let listTools = "tools/list"
        static let callTool = "tools/call"
        static let initialized = "notifications/initialized"
    }
}

struct MCPError: Swift.Error {
    let code: Int
    let message: String
    let status: Int
    let data: Property?

    init(code: Int, message: String, status: Int = 200, data: Property? = nil) {
        self.code = code
        self.message = message
        self.status = status
        self.data = data
    }

    // JSON-RPC 2.0
    static func parse() -> Self { .init(code: -32700, message: "Parse error", status: 400) }
    static func invalidRequest(_ message: String = "Invalid Request", status: Int = 400) -> Self {
        .init(code: -32600, message: message, status: status)
    }
    static func notFound(_ message: String, status: Int = 404) -> Self {
        .init(code: -32601, message: message, status: status)
    }
    static func invalidParameters(_ message: String, status: Int = 200) -> Self {
        .init(code: -32602, message: message, status: status)
    }
    static func unavailable(_ message: String, status: Int = 500) -> Self {
        .init(code: -32603, message: message, status: status)
    }

    // MCP
    static func headerMismatch(_ header: String) -> Self {
        .init(code: -32020, message: "Header mismatch: \(header) does not match the request body.", status: 400)
    }
    static func unsupportedVersion(requested: String, supported: String) -> Self {
        .init(
            code: -32022,
            message: "Unsupported protocol version: \(requested)",
            status: 400,
            data: .object(["requested": .string(requested), "supported": .array([.string(supported)])])
        )
    }
}
