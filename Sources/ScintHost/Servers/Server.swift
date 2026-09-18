import Foundation


struct MCPServer {
    let bridge: any ScintMCPBridge
    let transport: StdioTransport

    init(
        bridge: any ScintMCPBridge,
        transport: StdioTransport = .init()
    ) {
        self.bridge = bridge
        self.transport = transport
    }

    func run() async throws {
        func failure(
            id: Property?,
            code: Int,
            message: String,
            data: Property? = nil
        ) -> JSONRPCMessage {
            var error: [String: Property] = [
                "code": .integer(code),
                "message": .string(message)
            ]
            if let data { error["data"] = data }
            return .response(.error(id: id, error: .object(error)))
        }

        func success(
            id: Property,
            fields supplied: [String: Property],
            cacheScope: String? = nil
        ) -> JSONRPCMessage {
            var fields = supplied
            fields["resultType"] = .string("complete")
            if let cacheScope {
                fields["ttlMs"] = .integer(0)
                fields["cacheScope"] = .string(cacheScope)
            }

            var metadata = fields["_meta"]?.object ?? [:]
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            metadata["io.modelcontextprotocol/serverInfo"] = .object([
                "name": .string("scint"),
                "version": .string(version)
            ])
            fields["_meta"] = .object(metadata)
            return .response(.result(id: id, result: .object(fields)))
        }

        func process(id: Property, method: String, params: Property?) async -> JSONRPCMessage {
            guard case .object(let parameters)? = params,
                  case .object(let metadata)? = parameters["_meta"]
            else {
                return failure(id: id, code: -32602, message: "Request metadata is required.")
            }

            guard let requestedVersion = metadata["io.modelcontextprotocol/protocolVersion"]?.string else {
                return failure(id: id, code: -32602, message: "Protocol version metadata is required.")
            }
            guard requestedVersion == MCPProtocol.version else {
                return failure(
                    id: id,
                    code: -32022,
                    message: "Unsupported protocol version: \(requestedVersion)",
                    data: .object([
                        "requested": .string(requestedVersion),
                        "supported": .array([.string(MCPProtocol.version)])
                    ])
                )
            }
            guard case .object? = metadata["io.modelcontextprotocol/clientCapabilities"] else {
                return failure(id: id, code: -32602, message: "Client capabilities metadata is required.")
            }
            if let client = metadata["io.modelcontextprotocol/clientInfo"] {
                guard case .object(let fields) = client,
                      fields["name"]?.string != nil,
                      fields["version"]?.string != nil
                else {
                    return failure(id: id, code: -32602, message: "Client information metadata is invalid.")
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

            let operation: ScintMCPOperation
            switch method {
                case "tools/list":
                    let cursor = parameters["cursor"]
                    guard cursor == nil || cursor?.string != nil else {
                        return failure(id: id, code: -32602, message: "Cursor must be a string.")
                    }
                    operation = .listTools(cursor: cursor?.string)

                case "tools/call":
                    guard let name = parameters["name"]?.string else {
                        return failure(id: id, code: -32602, message: "Tool name is required.")
                    }
                    let arguments: [String: Property]
                    if let supplied = parameters["arguments"] {
                        guard case .object(let object) = supplied else {
                            return failure(id: id, code: -32602, message: "Tool arguments must be an object.")
                        }
                        arguments = object
                    } else {
                        arguments = [:]
                    }
                    operation = .callTool(name: name, arguments: arguments)

                case "resources/list":
                    let cursor = parameters["cursor"]
                    guard cursor == nil || cursor?.string != nil else {
                        return failure(id: id, code: -32602, message: "Cursor must be a string.")
                    }
                    operation = .listResources(cursor: cursor?.string)

                case "resources/read":
                    guard let uri = parameters["uri"]?.string,
                          let parsed = URL(string: uri),
                          parsed.scheme != nil
                    else {
                        return failure(id: id, code: -32602, message: "Resource URI is required.")
                    }
                    operation = .readResource(uri: uri)

                default:
                    return failure(id: id, code: -32601, message: "Method not found: \(method)")
            }

            guard let encodedContext = metadata[MCPProtocol.contextMetadataKey]?.string,
                  let context = UUID(uuidString: encodedContext)
            else {
                return failure(id: id, code: -32602, message: "Scint context metadata is required.")
            }

            do {
                let fields = try await bridge.perform(.init(context: context, operation: operation))
                let cacheScope: String? = switch operation {
                    case .callTool: nil
                    case .listTools, .listResources, .readResource: "private"
                }
                return success(id: id, fields: fields, cacheScope: cacheScope)
            } catch let error as ScintMCPBridgeError {
                switch error {
                    case .contextNotFound(let context):
                        return failure(
                            id: id,
                            code: -32602,
                            message: "Scint context was not found.",
                            data: .object(["context": .string(context.uuidString.lowercased())])
                        )
                    case .invalidArguments(let message):
                        return failure(id: id, code: -32602, message: message)
                    case .resourceNotFound(let uri):
                        return failure(
                            id: id,
                            code: -32602,
                            message: "Resource not found.",
                            data: .object(["uri": .string(uri)])
                        )
                    case .toolNotFound(let name):
                        return failure(id: id, code: -32602, message: "Unknown tool: \(name)")
                }
            } catch {
                return failure(id: id, code: -32603, message: "Internal error.")
            }
        }

        while let data = try await transport.read() {
            let message: JSONRPCMessage
            do {
                do {
                    _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                } catch {
                    try await transport.write(try failure(
                        id: nil,
                        code: -32700,
                        message: "Parse error."
                    ).encodeLine())
                    continue
                }
                message = try JSONRPCMessage.decode(data)
            } catch {
                try await transport.write(try failure(
                    id: nil,
                    code: -32600,
                    message: "Invalid Request."
                ).encodeLine())
                continue
            }

            switch message {
                case .request(let id, let method, let params):
                    try await transport.write(try await process(
                        id: id,
                        method: method,
                        params: params
                    ).encodeLine())

                case .notification, .response:
                    continue
            }
        }
    }
}
