import Foundation


struct MCPServer {
    let bridge: any ScintHostBridge

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

    private func initialized(_ method: String, _ parameters: [String: Property],
                             context: UUID?) async throws -> [String: Property] {

        switch method {
            case "initialize":
                let requested = parameters["protocolVersion"]?.string ?? ""
                return [
                    "protocolVersion": .string(
                        MCPProtocol.initializedVersions.contains(requested) ? requested : MCPProtocol.initializedVersion
                    ),
                    "capabilities": .object([
                        "tools": .object([:]),
                        "resources": .object([:])
                    ]),
                    "serverInfo": serverInfo
                ]
            case "ping":
                return [:]
            default:
                return try await perform(try operation(method, parameters), context: context)
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
                    else {
                throw Failure(code: -32602, message: "Client information metadata is invalid.")
            }
        }

        if method == "server/discover" {
            return success(
                id: id,
                fields: [
                    "supportedVersions": .array([.string(MCPProtocol.version)]),
                    "capabilities": .object([
                        "tools": .object([:]),
                        "resources": .object([:])
                    ])
                ],
                cacheScope: "public"
            )
        }

        let operation = try operation(method, parameters)
        let cacheScope: String? = switch operation {
            case .callTool: nil
            case .listTools, .listResources, .readResource: "private"
        }
        return success(id: id, fields: try await perform(operation, context: context), cacheScope: cacheScope)
    }

    private func operation(_ method: String, _ parameters: [String: Property]) throws -> ScintHostOperation {
        switch method {
            case "tools/list":
                let cursor = parameters["cursor"]
                guard cursor == nil || cursor?.string != nil else {
                    throw Failure(code: -32602, message: "Cursor must be a string.")
                }
                return .listTools(cursor: cursor?.string)

            case "tools/call":
                guard let name = parameters["name"]?.string else {
                    throw Failure(code: -32602, message: "Tool name is required.")
                }
                let arguments: [String: Property]
                if let supplied = parameters["arguments"] {
                    guard case .object(let object) = supplied else {
                        throw Failure(code: -32602, message: "Tool arguments must be an object.")
                    }
                    arguments = object
                } else {
                    arguments = [:]
                }
                return .callTool(name: name, arguments: arguments)

            case "resources/list":
                let cursor = parameters["cursor"]
                guard cursor == nil || cursor?.string != nil else {
                    throw Failure(code: -32602, message: "Cursor must be a string.")
                }
                return .listResources(cursor: cursor?.string)

            case "resources/read":
                guard let uri = parameters["uri"]?.string,
                      let parsed = URL(string: uri),
                      parsed.scheme != nil
                else {
                    throw Failure(code: -32602, message: "Resource URI is required.")
                }
                return .readResource(uri: uri)

            default:
                throw Failure(code: -32601, message: "Method not found: \(method)")
        }
    }

    private func perform(_ operation: ScintHostOperation, context: UUID?) async throws -> [String: Property] {
        guard let context else {
            throw Failure(code: -32602, message: "Scint context is required.")
        }

        do {
            return try await bridge.perform(.init(context: context, operation: operation))
        } catch let error as ScintHostBridgeError {
            switch error {
                case .contextNotFound(let context):
                    throw Failure(
                        code: -32602,
                        message: "Scint context was not found.",
                        data: .object(["context": .string(context.uuidString.lowercased())])
                    )
                case .invalidArguments(let message):
                    throw Failure(code: -32602, message: message)
                case .resourceNotFound(let uri):
                    throw Failure(
                        code: -32602,
                        message: "Resource not found.",
                        data: .object(["uri": .string(uri)])
                    )
                case .toolNotFound(let name):
                    throw Failure(code: -32602, message: "Unknown tool: \(name)")
            }
        }
    }

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

    private func success(id: Property, fields supplied: [String: Property],
                         cacheScope: String? = nil) -> JSONRPCMessage {

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
