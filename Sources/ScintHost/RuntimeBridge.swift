import Foundation


struct RuntimeBridge: ScintHostBridge, @unchecked Sendable {
    private enum Tool: String, CaseIterable {
        case contentNew = "content.new"
        case contentWith = "content.with"
        case contentUpdate = "content.update"
        case structureNew = "structure.new"
        case structureWith = "structure.with"
        case structureUpdate = "structure.update"
        case structureDelete = "structure.delete"
        case composeStart = "compose.start"
        case composeStop = "compose.stop"
        case composeContext = "compose.context"

        var description: String {
            switch self {
                case .contentNew: "Create a material in a space."
                case .contentWith: "Return a material as a structured runtime value."
                case .contentUpdate: "Append or replace one block in a material."
                case .structureNew: "Create a child space."
                case .structureWith: "Return a space as a structured runtime value."
                case .structureUpdate: "Add a material or space to a space."
                case .structureDelete: "Delete a material or space through the runtime."
                case .composeStart: "Start a space through its configured harness."
                case .composeStop: "Stop a running space."
                case .composeContext: "Return the current composition state for a space."
            }
        }

        var inputSchema: Property {
            let address: Property = .object([
                "type": .string("string"),
                "description": .string("A scint:// resource URI or descriptor UUID.")
            ])
            let block: Property = .object([
                "type": .string("object"),
                "properties": .object([
                    "kind": .object(["enum": .array(["artifact", "command", "material", "task", "text"])]),
                    "reference": address,
                    "text": .object(["type": .string("string")]),
                    "done": .object(["type": .string("boolean")]),
                    "id": .object(["type": .string("string"), "format": .string("uuid")])
                ]),
                "required": .array([.string("kind")]),
                "additionalProperties": .bool(false)
            ])

            return switch self {
                case .contentNew:
                    .schema([
                        "name": .object(["type": .string("string")]),
                        "blocks": .object(["type": .string("array"), "items": block]),
                        "space": address
                    ], required: ["name"])
                case .contentWith:
                    .schema(["content": address], required: ["content"])
                case .contentUpdate:
                    .schema([
                        "material": address,
                        "block": block,
                        "index": .object(["type": .string("integer"), "minimum": .integer(0)])
                    ], required: ["material", "block"])
                case .structureNew:
                    .schema([
                        "name": .object(["type": .string("string")]),
                        "parent": address
                    ], required: ["name"])
                case .structureWith:
                    .schema(["content": address], required: ["content"])
                case .structureUpdate:
                    .schema(["content": address, "space": address], required: ["content"])
                case .structureDelete:
                    .schema(["content": address], required: ["content"])
                case .composeStart, .composeStop, .composeContext:
                    .schema(["space": address])
            }
        }

        var definition: Property {
            .object([
                "name": .string(rawValue),
                "description": .string(description),
                "inputSchema": inputSchema
            ])
        }
    }

    @MainActor func perform(_ request: ScintHostRequest) async throws -> [String: Property] {
        guard let composition = ContextProvider.context.first(where: {
            $0.space.contextId == request.context || $0.space.id == request.context
        }) else {
            throw ScintHostBridgeError.contextNotFound(request.context)
        }

        return switch request.operation {
            case .listTools:
                ["tools": .array(Tool.allCases.map(\.definition))]
            case .callTool(let name, let arguments):
                try await call(name, arguments: arguments, context: composition.space)
            case .listResources:
                ["resources": .array(resources(in: composition.space).map(resource))]
            case .readResource(let uri):
                try readResource(uri, in: composition.space)
        }
    }

    private func call(_ name: String ,arguments: [String: Property],context: Reference) async throws -> [String: Property] {
        guard let tool = Tool(rawValue: name) else { throw ScintHostBridgeError.toolNotFound(name) }

        let value: Property
        switch tool {
            case .contentNew:
                let name = try string("name", in: arguments)
                let space = try reference("space", in: arguments) ?? context
                let blocks = try arguments["blocks"]?.array?.map(block) ?? []
                value = .fromCodable(ContextProvider.content.new(name, blocks, in: space))

            case .contentWith:
                let ref = try requiredReference("content", in: arguments)
                guard let material = ContextProvider.content.with(ref) else {
                    throw ScintHostBridgeError.invalidArguments("content does not reference a material.")
                }
                value = .fromCodable(material)

            case .contentUpdate:
                let ref = try requiredReference("material", in: arguments)
                guard let supplied = arguments["block"] else {
                    throw ScintHostBridgeError.invalidArguments("block is required.")
                }
                guard let updated = ContextProvider.content.update(
                    ref,
                    with: try block(supplied),
                    at: try integer("index", in: arguments)
                ) else {
                    throw ScintHostBridgeError.invalidArguments("material does not reference a material.")
                }
                value = .fromCodable(updated)

            case .structureNew:
                let parent = try reference("parent", in: arguments) ?? context
                value = .fromCodable(ContextProvider.structure.new(try string("name", in: arguments), in: parent))

            case .structureWith:
                let ref = try requiredReference("content", in: arguments)
                guard let space = ContextProvider.structure.with(ref) else {
                    throw ScintHostBridgeError.invalidArguments("content does not reference a space.")
                }
                value = .fromCodable(space)

            case .structureUpdate:
                let member = try requiredReference("content", in: arguments)
                let space = try reference("space", in: arguments) ?? context
                guard let updated = ContextProvider.structure.update(member, in: space) else {
                    throw ScintHostBridgeError.invalidArguments("space does not reference a space.")
                }
                value = .fromCodable(updated)

            case .structureDelete:
                value = .fromCodable(try await ContextProvider.structure.delete(
                    try requiredReference("content", in: arguments)
                ))

            case .composeStart:
                value = try compose(.start, for: try reference("space", in: arguments) ?? context)
            case .composeStop:
                value = try compose(.stop, for: try reference("space", in: arguments) ?? context)
            case .composeContext:
                let space = try reference("space", in: arguments) ?? context
                guard let current = ContextProvider.compose.context(for: space) else {
                    throw ScintHostBridgeError.invalidArguments("space has no composition.")
                }
                value = compose(current)
        }

        return result(value)
    }

    private func compose(_ activity: ComposeTool.Activity, for space: Reference) throws -> Property {
        guard let current = ContextProvider.compose.compose(activity, for: space) else {
            throw ScintHostBridgeError.invalidArguments("The requested composition transition is unavailable.")
        }
        return compose(current)
    }

    private func compose(_ value: Composition) -> Property {
        .object([
            "space": .fromCodable(value.space),
            "state": .string(String(describing: value.state))
        ])
    }

    private func result(_ value: Property) -> [String: Property] {
        var fields: [String: Property] = ["structuredContent": value, "isError": .bool(false)]
        if let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) {
            fields["content"] = .array([.object(["type": .string("text"), "text": .string(text)])])
        }
        return fields
    }

    private func resources(in space: Reference) -> [Reference] {
        guard let value = ContextProvider.structure.with(space) else { return [] }
        return ([value.ref] + Array(value.spaces) + value.materials)
            .filter { $0.descriptor.published }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    private func resource(_ ref: Reference) -> Property {
        .object([
            "uri": .string(Reference.Link.url(for: ref)?.absoluteString ?? "scint://reference/\(ref.descriptorId.uuidString.lowercased())"),
            "name": .string(ref.descriptor.name),
            "description": .string(ref.descriptor.description),
            "mimeType": .string("application/json")
        ])
    }

    private func readResource(_ uri: String, in space: Reference) throws -> [String: Property] {
        guard let url = URL(string: uri),
              let ref = Reference.Link.reference(in: url),
              resources(in: space).contains(ref)
        else { throw ScintHostBridgeError.resourceNotFound(uri) }

        let value: Property
        if let material = ContextProvider.content.with(ref) { value = .fromCodable(material) }
        else if let structure = ContextProvider.structure.with(ref) { value = .fromCodable(structure) }
        else { throw ScintHostBridgeError.resourceNotFound(uri) }

        guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else {
            throw ScintHostBridgeError.resourceNotFound(uri)
        }
        return ["contents": .array([.object([
            "uri": .string(uri),
            "mimeType": .string("application/json"),
            "text": .string(text)
        ])])]
    }

    private func reference(_ name: String, in arguments: [String: Property]) throws -> Reference? {
        guard let value = arguments[name] else { return nil }
        guard let address = value.string,
              let ref = Reference.Link.reference(in: address) ?? UUID(uuidString: address).flatMap(Catalog.shared.get)
        else { throw ScintHostBridgeError.invalidArguments("\(name) must be a valid Scint address.") }
        return ref
    }

    private func requiredReference(_ name: String, in arguments: [String: Property]) throws -> Reference {
        guard let ref = try reference(name, in: arguments) else {
            throw ScintHostBridgeError.invalidArguments("\(name) is required.")
        }
        return ref
    }

    private func string(_ name: String, in arguments: [String: Property]) throws -> String {
        guard let value = arguments[name]?.string, !value.isEmpty else {
            throw ScintHostBridgeError.invalidArguments("\(name) must be a non-empty string.")
        }
        return value
    }

    private func integer(_ name: String, in arguments: [String: Property]) throws -> Int? {
        guard let value = arguments[name] else { return nil }
        guard let integer = value.int, integer >= 0 else {
            throw ScintHostBridgeError.invalidArguments("\(name) must be a non-negative integer.")
        }
        return integer
    }

    private func block(_ value: Property) throws -> Material.Block {
        guard let object = value.object, let kind = object["kind"]?.string else {
            throw ScintHostBridgeError.invalidArguments("block.kind is required.")
        }
        let id: UUID
        if let supplied = object["id"]?.string {
            guard let parsed = UUID(uuidString: supplied) else {
                throw ScintHostBridgeError.invalidArguments("block.id must be a UUID.")
            }
            id = parsed
        } else {
            id = UUID()
        }

        switch kind {
            case "text":
                guard let text = object["text"]?.string else {
                    throw ScintHostBridgeError.invalidArguments("A text block requires text.")
                }
                return .text(id, text)
            case "task":
                guard let text = object["text"]?.string else {
                    throw ScintHostBridgeError.invalidArguments("A task block requires text.")
                }
                return .task(id, text, object["done"]?.bool ?? false)
            case "artifact", "command", "material":
                guard let address = object["reference"]?.string,
                      let ref = Reference.Link.reference(in: address) ?? UUID(uuidString: address).flatMap(Catalog.shared.get)
                else { throw ScintHostBridgeError.invalidArguments("A \(kind) block requires a valid reference.") }
                return switch kind {
                    case "artifact": .artifact(ref)
                    case "command": .command(ref)
                    default: .material(ref)
                }
            default:
                throw ScintHostBridgeError.invalidArguments("Unknown block kind: \(kind).")
        }
    }
}
