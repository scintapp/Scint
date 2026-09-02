import Foundation


struct MCPSession {
    let context: ContextId
    let space: Reference
    let tools: [any Tool]

    static func resolve(_ request: MCPRequest) async throws(MCPError) -> Self {
        guard let context = bearer(request.http) else {
            throw MCPError.invalidRequest("Scint context is required.", status: 401)
        }

        let outcome = await MainActor.run { () -> Resolution in
            guard let composition = Runtime.shared.resolve().first(where: { holds(context, $0) })
                    else { return .refused(unmatched(context)) }

//            guard composition.space.type == Space.self else {
//                return .refused(
//                    "\(composition.space.descriptor.name) is a "
//                    + "\(composition.space.type.map { String(describing: $0).lowercased() } ?? "unknown") — "
//                    + "tools are served from a space."
//                )
//            }

            guard composition.state != .inactive else {
                return .refused(
                    "\(composition.space.descriptor.name) is composed but not running. Start it, or "
                    + "dispatch through it, before calling its tools."
                )
            }

            return .session(composition.space, Tools.all(in: composition.space))
        }

        switch outcome {
            case .refused(let reason): throw MCPError.invalidRequest(reason, status: 403)
            case .session(let space, let tools): return Self(context: context, space: space, tools: tools)
        }
    }

    func tool(named name: String) -> (any Tool)? { tools.first { $0.name == name } }

    @MainActor
    private static func holds(_ context: ContextId, _ composition: Composition) -> Bool {
        if composition.space.contextId == context { return true }

        let transcript = composition.transcript
        if transcript.contextId == context { return true }

        return Transcript.with(transcript, { $0.branches })?
            .contains { $0.contextId == context } ?? false
    }

    private enum Resolution {
        case session(Reference, [any Tool])
        case refused(String)
    }

    @MainActor
    private static func unmatched(_ context: ContextId) -> String {
        let spaces = Runtime.shared.all(as: Space.self).map(\.0)
        + Runtime.shared.all(as: Workspace.self).map(\.0)

        guard let space = spaces.first(where: { $0.contextId == context }) else {
            let transcript = Runtime.shared.all(as: Transcript.self).map(\.0)
                .first { $0.contextId == context }
            if let transcript {
                return "\(transcript.descriptor.name) is a transcript with this context, but its "
                + "space has no running composition."
            }
            return "Nothing has this context. The token may name something that has been replaced — "
            + "reseeding mints new references, and a token issued before it is stale."
        }

        let harness = Space.with(space, { $0.harness }) ?? Workspace.with(space, { $0.harness }) ?? nil
        guard harness != nil else {
            return "\(space.descriptor.name) has this context but no harness, so it has no composition."
        }
        return "\(space.descriptor.name) has this context but has not been composed. Start it first."
    }

    private static func bearer(_ request: HTTPRequest) -> ContextId? {
        guard let authorization = request.header("Authorization") else { return nil }
        let parts = authorization.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, String(parts[0]).caseInsensitiveCompare("Bearer") == .orderedSame
                else { return nil }
        return UUID(uuidString: String(parts[1]))
    }
}

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
