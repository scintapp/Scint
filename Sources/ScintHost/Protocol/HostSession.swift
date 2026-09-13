import Foundation


enum MCPHandshake {
    static func validate(_ request: MCPRequest) throws(MCPError) {
        if let meta = request.parameters["_meta"]?.object,
           let requested = meta["io.modelcontextprotocol/protocolVersion"]?.string {
            if let client = meta["io.modelcontextprotocol/clientInfo"], !isValidImplementation(client) {
                throw MCPError.invalidParameters("Client information is invalid.", status: 400)
            }
            guard request.http.header("MCP-Protocol-Version") == requested else {
                throw MCPError.headerMismatch("MCP-Protocol-Version")
            }
            guard MCPResponse.supportedVersions.contains(requested) else {
                throw MCPError.unsupportedVersion(requested: requested, supported: MCPResponse.protocolVersion)
            }
        }

        if let header = request.http.header("Mcp-Method"), header != request.method {
            throw MCPError.headerMismatch("Mcp-Method")
        }
        if request.method == MCPRequest.Method.callTool,
           let header = request.http.header("Mcp-Name").flatMap(decoded),
           header != request.parameters["name"]?.string {
            throw MCPError.headerMismatch("Mcp-Name")
        }
    }

    private static func isValidImplementation(_ value: Property) -> Bool {
        guard let value = value.object else { return false }
        return value["name"]?.string != nil && value["version"]?.string != nil
    }

    private static func decoded(_ value: String) -> String? {
        let prefix = "=?base64?"
        guard value.hasPrefix(prefix), value.hasSuffix("?=") else { return value }
        let encoded = String(value.dropFirst(prefix.count).dropLast(2))
        guard let data = Data(base64Encoded: encoded) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Bound to the live runtime context, never to an identity supplied in tool arguments.
struct ToolIdentity: Sendable {
    let context: ContextId
    let space: Reference
    let transcript: Reference

    @MainActor
    static func resolve(_ token: ContextId) throws -> Self {
        let matches = Runtime.shared.resolve().compactMap { composition -> ToolIdentity? in
            guard let live = Composer.shared.context(composition.space), !live.handlers.isEmpty,
                  (Space.with(composition.space, { $0.harness }) ?? nil) != nil else { return nil }
            let identities = [composition.space.contextId, live.transcript.contextId]
                + live.handlers.map { $0.transcript.contextId }
            guard identities.contains(token) else { return nil }
            return Self(context: token, space: composition.space, transcript: live.transcript)
        }
        guard matches.count == 1, let identity = matches.first else {
            throw ToolFailure("The context does not identify a running composition. Start the space and use its current SCINT_CONTEXT bearer.")
        }
        return identity
    }

    @MainActor
    func verify() throws {
        let current = try Self.resolve(context)
        guard current.space == space, current.transcript == transcript else {
            throw ToolFailure("This context has been replaced. Reconnect with its current identity.")
        }
    }
}

struct MCPSession {
    let identity: ToolIdentity
    let tools: [any Tool]
    var context: ContextId { identity.context }
    var space: Reference { identity.space }

    static func resolve(_ request: MCPRequest) async throws(MCPError) -> Self {
        guard let context = bearer(request.http) else {
            throw MCPError.invalidRequest("Scint context is required.", status: 401)
        }
        do {
            return try await MainActor.run {
                let identity = try ToolIdentity.resolve(context)
                return Self(identity: identity, tools: Tools.all(in: identity))
            }
        } catch {
            throw MCPError.invalidRequest(String(describing: error), status: 403)
        }
    }

    func tool(named name: String) -> (any Tool)? { tools.first { $0.name == name } }

    private static func bearer(_ request: HTTPRequest) -> ContextId? {
        guard let authorization = request.header("Authorization") else { return nil }
        let parts = authorization.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, String(parts[0]).caseInsensitiveCompare("Bearer") == .orderedSame
                else { return nil }
        return UUID(uuidString: String(parts[1]))
    }
}
