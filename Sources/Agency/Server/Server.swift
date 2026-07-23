import AgencyRuntime
import Foundation
import MCP
import OSLog

typealias Value = AgencyRuntime.Value

actor Server {
    static let host = "127.0.0.1"
    static let port: UInt16 = 7345
    static let endpoint = "/mcp"
    static var url: URL { URL(string: "http://\(host):\(port)\(endpoint)")! }
    static var linkArguments: [String] {
        ["mcp", "add", "agency", "--url", url.absoluteString, "--bearer-token-env-var", "AGENCY_CONTEXT"]
    }

    private static let logger = Logger(subsystem: "com.kaechle.Agency", category: "MCP")

    enum Error: Swift.Error, CustomStringConvertible {
        case invalidPort
        case unavailableContext

        var description: String {
            switch self {
                case .invalidPort: return "The MCP server port is invalid."
                case .unavailableContext: return "The Agency execution context is no longer active."
            }
        }
    }

    private struct Scope {
        let root: Reference
        let server: MCP.Server
        let transport: StatelessHTTPServerTransport
    }

    private let runtime: Runtime
    private let http = NetworkServer()
    private var scopes: [ContextId: Scope] = [:]

    init(runtime: Runtime = .shared) { self.runtime = runtime }

    func start() async throws {
        try await http.start(port: Self.port) { [weak self] request in
            guard let self else { return .error(statusCode: 500, .internalError("Agency server is unavailable.")) }
            return await self.handle(request)
        }
    }

    func stop() async {
        http.stop()
        for scope in scopes.values { await scope.server.stop() }
        scopes = [:]
    }

    private func handle(_ request: HTTPRequest) async -> HTTPResponse {
        guard request.path == Self.endpoint else {
            Self.logger.error("MCP \(request.method, privacy: .public) \(request.path ?? "", privacy: .public) -> 404")
            return .error(statusCode: 404, .invalidRequest("Not Found"))
        }
        guard let context = Self.context(from: request) else {
            Self.logger.error("MCP \(request.method, privacy: .public) missing context -> 401")
            return .error(statusCode: 401, .invalidRequest("Agency context is required."))
        }
        let composition = runtime.context().first(where: { $0.root.contextId == context })
        guard let composition,
              composition.root.type == Space.self,
              composition.state == .active || composition.state == .running
        else {
            if let scope = scopes.removeValue(forKey: context) { await scope.server.stop() }
            Self.logger.error("MCP \(request.method, privacy: .public) context \(context.uuidString, privacy: .public) unavailable -> 403")
            return .error(statusCode: 403, .invalidRequest(Error.unavailableContext.description))
        }

        do {
            if Self.initializing(request), let scope = scopes.removeValue(forKey: context) {
                await scope.server.stop()
            }
            let scope = try await scope(for: composition)
            let response = await scope.transport.handleRequest(request)
            Self.logger.info("MCP \(request.method, privacy: .public) context \(context.uuidString, privacy: .public) -> \(response.statusCode)")
            return response
        } catch {
            Self.logger.error("MCP \(request.method, privacy: .public) context \(context.uuidString, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return .error(statusCode: 500, .internalError(String(describing: error)))
        }
    }

    private func scope(for composition: Composition) async throws -> Scope {
        let context = composition.root.contextId
        if let scope = scopes[context], scope.root == composition.root { return scope }

        let transport = StatelessHTTPServerTransport()
        let server = MCP.Server(
            name: "agency",
            version: "0.1.0",
            title: "Agency",
            instructions: "Use the tools and resources provided by the active Agency execution context.",
            capabilities: .init(resources: .init(listChanged: false), tools: .init(listChanged: false))
        )
        await Self.configure(server, origin: composition.root, runtime: runtime)
        try await server.start(transport: transport)

        let scope = Scope(root: composition.root, server: server, transport: transport)
        scopes[context] = scope
        return scope
    }
}

private extension Server {
    static let commandPrefix = "agency."
    static let resourceScheme = "agency"
    static let resourceHost = "resource"

    static func configure(_ server: MCP.Server, origin: Reference, runtime: Runtime) async {
        await server.withMethodHandler(ListTools.self) { _ in
            let commands = commands(origin).map { commandTool($0, runtime: runtime) }
            let harnesses = HarnessTool.all(in: origin).compactMap(\.tool)
            return ListTools.Result(tools: commands + harnesses)
        }

        await server.withMethodHandler(CallTool.self) { params in
            if let harness = HarnessTool.find(params.name, in: origin) {
                return await harness.call(params.arguments)
            }
            guard let closure = closure(origin), let ref = command(params.name, in: closure) else {
                return CallTool.Result(content: [.text(text: "Unknown Agency tool: \(params.name)")], isError: true)
            }
            guard let command = Command.with(ref, { $0 }) else {
                return CallTool.Result(content: [.text(text: "Agency command is unavailable.")], isError: true)
            }

            let values: [String: Value]
            do {
                let available = Set(closure.content).union(closure.interfaces).union([origin])
                let supplied = try commandValues(params.arguments, command: command, available: available)
                values = try Parser.parse(supplied, parameters: command.parameters)
            } catch {
                return CallTool.Result(content: [.text(text: String(describing: error))], isError: true)
            }

            let (stream, continuation) = AsyncStream<Signal>.makeStream()
            let environment = ["AGENCY_CONTEXT": origin.contextId.uuidString.lowercased()]
            guard let result = command.dispatch(values, environment: environment, output: { signal in
                continuation.yield(signal)
                if signal.terminal { continuation.finish() }
            }) else {
                return CallTool.Result(content: [.text(text: "Agency command could not be dispatched.")], isError: true)
            }
            if let error = result.error {
                continuation.finish()
                return CallTool.Result(content: [.text(text: error)], isError: true)
            }

            var output: [String] = []
            var failed = false
            for await signal in stream {
                switch signal {
                    case .updated(let value): output.append(contentsOf: value.rendered)
                    case .failed(let value): output.append(contentsOf: value.rendered); failed = true
                    case .trigger, .started, .completed: break
                }
            }
            return CallTool.Result(content: [.text(text: output.joined(separator: "\n"))], isError: failed)
        }

        await server.withMethodHandler(ListResources.self) { _ in
            guard let closure = closure(origin) else { return ListResources.Result(resources: []) }
            let refs = [origin] + content(closure)
            return ListResources.Result(resources: refs.map { resource($0, runtime: runtime) })
        }

        await server.withMethodHandler(ReadResource.self) { params in
            guard let closure = closure(origin), let ref = resource(params.uri, origin: origin, closure: closure) else {
                throw MCPError.invalidParams("Unknown Agency resource: \(params.uri)")
            }
            return ReadResource.Result(contents: [try resourceContent(ref, uri: params.uri, closure: closure)])
        }
    }

    static func context(from request: HTTPRequest) -> ContextId? {
        guard let authorization = request.header(HTTPHeaderName.authorization) else { return nil }
        let parts = authorization.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, String(parts[0]).caseInsensitiveCompare("Bearer") == .orderedSame else { return nil }
        return UUID(uuidString: String(parts[1]))
    }

    static func initializing(_ request: HTTPRequest) -> Bool {
        guard let body = request.body,
              let message = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return false }
        return message["method"] as? String == Initialize.name
    }

    static func closure(_ origin: Reference) -> Closure? {
        Space.with(origin, { $0.closure }).flatMap { Closure.with($0, { $0 }) }
    }

    static func commands(_ origin: Reference) -> [Reference] {
        guard let closure = closure(origin) else { return [] }
        return closure.commands.filter { $0.descriptor.published }.sorted { $0.descriptor.name < $1.descriptor.name }
    }

    static func content(_ closure: Closure) -> [Reference] {
        closure.content.filter { ref in
            ref.descriptor.published && (ref.type == Sheet.self || ref.type == Artifact.self || ref.type == Transcript.self)
        }.sorted { $0.descriptor.name < $1.descriptor.name }
    }

    static func command(_ name: String, in closure: Closure) -> Reference? {
        closure.commands.first { commandName($0) == name && $0.descriptor.published }
    }

    static func commandTool(_ ref: Reference, runtime: Runtime) -> Tool {
        let descriptor = runtime.get(ref)
        return Tool(
            name: commandName(ref),
            title: descriptor.name,
            description: descriptor.description.isEmpty ? "Run \(descriptor.name)." : descriptor.description,
            inputSchema: commandInputSchema(ref),
            annotations: .init(title: descriptor.name, readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: false)
        )
    }

    static func commandName(_ ref: Reference) -> String {
        let name = ref.descriptor.name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        return commandPrefix + (name.isEmpty ? "command" : name) + "_" + ref.id.uuidString.prefix(8).lowercased()
    }

    static func commandInputSchema(_ ref: Reference) -> MCP.Value {
        let parameters = Command.with(ref, { $0.parameters }) ?? []
        let properties = parameters.reduce(into: [String: MCP.Value]()) { schema, parameter in
            guard case .argument(let name, let type, _, _) = parameter else { return }
            schema[name] = valueSchema(type)
        }
        let required = parameters.compactMap { parameter -> MCP.Value? in
            guard case .argument(let name, _, true, _) = parameter else { return nil }
            return .string(name)
        }
        var schema: [String: MCP.Value] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false)
        ]
        if !required.isEmpty { schema["required"] = .array(required) }
        return .object(schema)
    }

    static func valueSchema(_ value: Value) -> MCP.Value {
        switch value {
            case .bool: return .object(["type": .string("boolean")])
            case .integer: return .object(["type": .string("integer")])
            case .decimal: return .object(["type": .string("number")])
            case .string, .reference: return .object(["type": .string("string")])
            case .sequence(let values):
                return .object(["type": .string("array"), "items": values.first.map(valueSchema) ?? .object(["type": .string("string")])])
            case .collection(let values):
                if values.count == 1, let value = values.values.first { return valueSchema(value) }
                return .object(["type": .string("object"), "properties": .object(values.mapValues(valueSchema))])
        }
    }

    static func commandValues(_ values: [String: MCP.Value]?, command: Command, available: Set<Reference>) throws -> [String: Value] {
        let supplied = values ?? [:]
        return try supplied.reduce(into: [String: Value]()) { result, entry in
            guard let template = command.parameters.compactMap({ parameter -> (String, Value)? in
                guard case .argument(let name, let type, _, _) = parameter else { return nil }
                return (name, type)
            }).first(where: { $0.0 == entry.key })?.1 else { throw ParsingError.unexpectedArguments([entry.key]) }
            result[entry.key] = try value(entry.value, as: template, available: available)
        }
    }

    static func value(_ supplied: MCP.Value, as template: Value, available: Set<Reference>) throws -> Value {
        switch template {
            case .reference(let expected):
                guard case .string(let value) = supplied,
                      let id = UUID(uuidString: value) ?? URL(string: value).flatMap({ UUID(uuidString: $0.lastPathComponent) }),
                      let ref = available.first(where: { ($0.id == id || $0.descriptorId == id) && $0.typeId == expected.typeId })
                else { throw ParsingError.invalid("Reference argument is not available in this context.") }
                return .reference(ref)
            case .sequence(let values):
                guard case .array(let supplied) = supplied, let element = values.first else {
                    throw ParsingError.invalid("Argument expects a sequence.")
                }
                return .sequence(try supplied.map { try value($0, as: element, available: available) })
            case .collection(let values):
                if case .object(let supplied) = supplied {
                    return .collection(try supplied.reduce(into: [String: Value]()) { result, entry in
                        guard let template = values[entry.key] else { throw ParsingError.invalid("Argument has an invalid shape.") }
                        result[entry.key] = try value(entry.value, as: template, available: available)
                    })
                }
                guard values.count == 1, let (name, template) = values.first else {
                    throw ParsingError.invalid("Argument expects a collection.")
                }
                return .collection([name: try value(supplied, as: template, available: available)])
            default:
                guard let value = Value(property(supplied)) else { throw ParsingError.invalid("Argument has no value.") }
                return value
        }
    }

    static func property(_ value: MCP.Value) -> Property {
        switch value {
            case .null: return .null
            case .bool(let value): return .bool(value)
            case .int(let value): return .integer(value)
            case .double(let value): return .decimal(value)
            case .string(let value): return .string(value)
            case .data(_, let data): return .string(data.base64EncodedString())
            case .array(let values): return .array(values.map(property))
            case .object(let values): return .object(values.mapValues(property))
        }
    }

    static func resource(_ ref: Reference, runtime: Runtime) -> Resource {
        let descriptor = runtime.get(ref)
        return Resource(
            name: descriptor.name,
            uri: uri(ref),
            title: descriptor.name,
            description: descriptor.description.isEmpty ? nil : descriptor.description,
            mimeType: mimeType(ref)
        )
    }

    static func uri(_ ref: Reference) -> String {
        "\(resourceScheme)://\(resourceHost)/\(resourceKind(ref))/\(ref.id.uuidString.lowercased())"
    }

    static func resource(_ uri: String, origin: Reference, closure: Closure) -> Reference? {
        guard let components = URLComponents(string: uri), components.scheme == resourceScheme, components.host == resourceHost else { return nil }
        let path = components.path.split(separator: "/")
        guard path.count == 2, let id = UUID(uuidString: String(path[1])) else { return nil }
        return ([origin] + content(closure)).first { $0.id == id && resourceKind($0) == String(path[0]) }
    }

    static func resourceContent(_ ref: Reference, uri: String, closure: Closure) throws -> Resource.Content {
        switch ref.type {
            case is Space.Type:
                let description = ref.descriptor.description
                let rendered = content(closure).compactMap { component -> String? in
                    let value = Value.reference(component).rendered.joined(separator: "\n")
                    return value.isEmpty ? nil : "## \(component.descriptor.name)\n\(value)"
                }.joined(separator: "\n\n")
                let document = ["# \(ref.descriptor.name)", description, rendered].filter { !$0.isEmpty }.joined(separator: "\n\n")
                return .text(document, uri: uri, mimeType: "text/markdown")

            case is Sheet.Type:
                return .text(Sheet.with(ref, { $0.rendered }) ?? "", uri: uri, mimeType: "text/markdown")

            case is Transcript.Type:
                return .text(Transcript.with(ref, { $0.rendered.joined(separator: "\n") }) ?? "", uri: uri, mimeType: "text/plain")

            case is Artifact.Type:
                guard let artifact = Artifact.with(ref, { $0 }), let url = artifact.handler.url else {
                    throw MCPError.invalidParams("Agency artifact is unavailable: \(uri)")
                }
                guard url.isFileURL, !artifact.handler.directory, let data = try? Data(contentsOf: url) else {
                    return .text(artifact.rendered, uri: uri, mimeType: mimeType(ref))
                }
                if let text = String(data: data, encoding: .utf8) { return .text(text, uri: uri, mimeType: mimeType(ref)) }
                return .binary(data, uri: uri, mimeType: mimeType(ref))

            default:
                throw MCPError.invalidParams("Unsupported Agency resource: \(uri)")
        }
    }

    static func resourceKind(_ ref: Reference) -> String {
        switch ref.type {
            case is Space.Type: return "space"
            case is Sheet.Type: return "sheet"
            case is Artifact.Type: return "artifact"
            default: return "component"
        }
    }

    static func mimeType(_ ref: Reference) -> String? {
        if ref.type == Space.self || ref.type == Sheet.self { return "text/markdown" }
        guard let handler = Artifact.with(ref, { $0.handler }) else { return nil }
        switch handler.url?.pathExtension.lowercased() {
            case "json": return "application/json"
            case "md", "markdown": return "text/markdown"
            case "txt", "log", "swift", "sh", "py", "js", "mjs": return "text/plain"
            case "html", "htm": return "text/html"
            case "css": return "text/css"
            case "pdf": return "application/pdf"
            case "png": return "image/png"
            case "jpg", "jpeg": return "image/jpeg"
            case "gif": return "image/gif"
            case "webp": return "image/webp"
            case "svg": return "image/svg+xml"
            default: return nil
        }
    }
}
