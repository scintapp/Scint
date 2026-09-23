import Foundation
import ScintRuntime


struct MCPServer {
    private struct Failure: Error {
        let code: Int
        let message: String
        var data: Property? = nil
    }

    func serve(_ transport: HTTPTransport) async throws {
        try await transport.start { request in
            guard request.path == MCPProtocol.endpoint else { return .init(status: 404) }
            guard request.method == "POST" else { return .init(status: 405) }
            guard request.isLoopback else { return .init(status: 403) }

            guard let response = await respond(to: request.body ?? Data(), context: request.bearer) else {
                return .init(status: 202)
            }
            guard let body = try? JSONEncoder().encode(response) else { return .init(status: 500) }
            return .init(status: 200, body: body)
        }
    }

    func respond(to data: Data, context: UUID?) async -> JSONRPCMessage? {
        guard (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else {
            return failure(id: nil, Failure(code: -32700, message: "Parse error."))
        }
        guard let message = try? JSONRPCMessage.decode(data) else {
            return failure(id: nil, Failure(code: -32600, message: "Invalid Request."))
        }
        guard case .request(let id, let method, let params) = message else { return nil }

        let parameters = params?.object ?? [:]
        let metadata = parameters["_meta"]?.object ?? [:]
        let context = metadata[MCPProtocol.contextMetadataKey]?.string.flatMap(UUID.init(uuidString:)) ?? context

        do {
            guard metadata["io.modelcontextprotocol/protocolVersion"] != nil else {
                return .response(.result(id: id, result: .object(try await initialized(method, parameters, context: context))))
            }
            return try await stateless(id: id, method, parameters, metadata: metadata, context: context)
        } catch let error as Failure {
            return failure(id: id, error)
        } catch {
            return failure(id: id, Failure(code: -32603, message: "Internal error."))
        }
    }

    private func initialized(_ method: String, _ parameters: [String: Property], context: UUID?) async throws -> [String: Property] {
        switch method {
            case "initialize":
                let requested = parameters["protocolVersion"]?.string ?? ""
                return [
                    "protocolVersion": .string(
                        MCPProtocol.initializedVersions.contains(requested) ? requested : MCPProtocol.initializedVersion
                    ),
                    "capabilities": capabilities,
                    "serverInfo": serverInfo
                ]
            case "ping":
                return [:]
            default:
                return try await tools(method, parameters, context: context)
        }
    }

    private func stateless(id: Property, _ method: String, _ parameters: [String: Property],
                           metadata: [String: Property], context: UUID?) async throws -> JSONRPCMessage {
        guard let requestedVersion = metadata["io.modelcontextprotocol/protocolVersion"]?.string else {
            throw Failure(code: -32602, message: "Protocol version metadata is required.")
        }
        guard requestedVersion == MCPProtocol.version else {
            throw Failure(
                code: -32022,
                message: "Unsupported protocol version: \(requestedVersion)",
                data: .object([
                    "requested": .string(requestedVersion),
                    "supported": .array([.string(MCPProtocol.version)])
                ])
            )
        }
        guard case .object? = metadata["io.modelcontextprotocol/clientCapabilities"] else {
            throw Failure(code: -32602, message: "Client capabilities metadata is required.")
        }
        if let client = metadata["io.modelcontextprotocol/clientInfo"] {
            guard case .object(let fields) = client,
                  fields["name"]?.string != nil,
                  fields["version"]?.string != nil
            else { throw Failure(code: -32602, message: "Client information metadata is invalid.") }
        }
        if method == "server/discover" {
            return success(
                id: id,
                fields: [
                    "supportedVersions": .array([.string(MCPProtocol.version)]),
                    "capabilities": capabilities
                ],
                cacheScope: "public"
            )
        }

        return success(id: id, fields: try await tools(method, parameters, context: context), cacheScope: method == "tools/list" ? "private" : nil)
    }

    @MainActor private func tools(_ method: String, _ parameters: [String: Property], context: UUID?) async throws -> [String: Property] {
        switch method {
            case "tools/list":
                return ["tools": .array(ContextProvider.tools.map { $0.tool.definition })]

            case "tools/call":
                guard let name = parameters["name"]?.string else { throw Failure(code: -32602, message: "Tool name is required.") }
                guard let context else { throw Failure(code: -32602, message: "Scint context is required.") }
                do {
                    guard let data = try await ContextProvider.call(name, parameters["arguments"]?.object ?? [:], context: context)
                    else { throw Failure(code: -32602, message: "Unknown tool: \(name)") }
                    let text = (try? JSONEncoder().encode(data)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    var result: [String: Property] = ["content": .array([["type": "text", "text": .string(text)]]), "isError": false]
                    if case .object = data { result["structuredContent"] = data }
                    return result
                } catch let error as ToolError {
                    return ["content": .array([["type": "text", "text": .string(error.message)]]), "isError": true]
                }

            default:
                throw Failure(code: -32601, message: "Method not found: \(method)")
        }
    }

    private var capabilities: Property { ["tools": .object([:])] }

    private var serverInfo: Property {
        .object([
            "name": .string("scint"),
            "version": .string(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
        ])
    }

    private func failure(id: Property?, _ failure: Failure) -> JSONRPCMessage {
        var error: [String: Property] = [
            "code": .integer(failure.code),
            "message": .string(failure.message)
        ]
        if let data = failure.data { error["data"] = data }
        return .response(.error(id: id, error: .object(error)))
    }

    private func success(id: Property, fields supplied: [String: Property], cacheScope: String? = nil) -> JSONRPCMessage {
        var fields = supplied
        fields["resultType"] = .string("complete")
        if let cacheScope {
            fields["ttlMs"] = .integer(0)
            fields["cacheScope"] = .string(cacheScope)
        }

        var metadata = fields["_meta"]?.object ?? [:]
        metadata["io.modelcontextprotocol/serverInfo"] = serverInfo
        fields["_meta"] = .object(metadata)
        return .response(.result(id: id, result: .object(fields)))
    }
}
