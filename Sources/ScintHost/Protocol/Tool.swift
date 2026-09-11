import Foundation



enum ToolNamespace: String, CaseIterable, Sendable {
    case content
    case interfaces
    case structures

    static func of(_ type: (any Resolvable.Type)?) -> ToolNamespace? {
        switch type {
            case is any Malleable.Type: return .content
            case is any Functional.Type: return .interfaces
            case is any Structural.Type: return .structures
            default: return nil
        }
    }

    static func of(_ ref: Reference) -> ToolNamespace? { of(ref.type) }

    static func of(name: String) -> ToolNamespace? {
        let parts = name.split(separator: ".")
        guard parts.count >= 2, parts[0] == prefix else { return nil }
        return ToolNamespace(rawValue: String(parts[1]))
    }

    static let prefix = "scint"

    func qualified(_ operation: String) -> String { "\(Self.prefix).\(rawValue).\(operation)" }
}

/// A tool call as a transcript recorded it, read back into the tool that was called.
enum ToolCall {
    case catalog(ToolNamespace, CatalogTool.Operation)
    case content(ContentTool.Action)
    case interface(InterfaceTool.Operation)
    case structure(StructureTool.Operation)

    var namespace: ToolNamespace {
        switch self {
            case .catalog(let namespace, _): namespace
            case .content: .content
            case .interface: .interfaces
            case .structure: .structures
        }
    }

    /// Harnesses record the name in their own spelling: Codex keeps `scint.structures.create`, while
    /// Claude prefixes the server and flattens the dots, as `mcp__scint__scint_structures_create`.
    static func named(_ name: String) -> ToolCall? {
        let parts = (name.components(separatedBy: "__").last ?? name).split(maxSplits: 2) { $0 == "." || $0 == "_" }
        guard parts.count == 3, parts[0] == ToolNamespace.prefix,
              let namespace = ToolNamespace(rawValue: String(parts[1]))
        else { return nil }

        let operation = String(parts[2])
        if let catalog = CatalogTool.Operation(rawValue: operation) { return .catalog(namespace, catalog) }

        return switch namespace {
            case .content: ContentTool.Action(rawValue: operation).map(ToolCall.content)
            case .interfaces: InterfaceTool.Operation(rawValue: operation).map(ToolCall.interface)
            case .structures: StructureTool.Operation(rawValue: operation).map(ToolCall.structure)
        }
    }
}

enum Tools {
    private static let providers: [ToolNamespace: [@MainActor (Reference) -> [any Tool]]] = [
        .content: [{ CatalogTool.all(.content, in: $0) }, { ContentTool.all(in: $0) }],
        .interfaces: [{ CatalogTool.all(.interfaces, in: $0) }, { InterfaceTool.all(in: $0) }],
        .structures: [{ CatalogTool.all(.structures, in: $0) }, { StructureTool.all(in: $0) }],
    ]

    @MainActor
    static func all(in origin: Reference) -> [any Tool] {
        ToolNamespace.allCases.flatMap { namespace in
            (providers[namespace] ?? []).flatMap { $0(origin) }
        }
    }

    static var populated: [ToolNamespace] { ToolNamespace.allCases.filter { providers[$0]?.isEmpty == false } }
}

protocol Tool: Sendable {
    var namespace: ToolNamespace { get }
    var value: String { get }
    var name: String { get }
    var title: String { get }
    var summary: String { get }

    var subject: Reference? { get }

    var parameters: [ToolParameter] { get }
    var inputSchema: Property { get }

    func call(_ arguments: Properties) async -> ToolResult
}

extension Tool {
    var name: String { namespace.qualified(value) }
    var subject: Reference? { nil }
    var parameters: [ToolParameter] { [] }
    var inputSchema: Property { ToolParameter.schema(for: parameters) }

    var definition: Property {
        var value: [String: Property] = [
            "name": .string(name),
            "title": .string(title),
            "description": .string(summary),
            "inputSchema": inputSchema
        ]
        if let subject, let url = Reference.Link.url(for: subject) {
            value["_meta"] = .object(["com.kaechle.scint/address": .string(url.absoluteString)])
        }
        return .object(value)
    }
}

struct ToolResult: Sendable {
    let text: String
    let isError: Bool

    static func ok(_ text: String) -> Self { Self(text: text, isError: false) }
    static func failure(_ text: String) -> Self { Self(text: text, isError: true) }
}

struct ToolParameter: Sendable {
    enum Kind: Sendable {
        case string
        case boolean
        case integer
        case number
        case reference
        case object
        case choice([String])
    }

    let name: String
    let kind: Kind
    let summary: String
    let required: Bool

    static func string(_ name: String, _ summary: String, required: Bool = true) -> Self {
        Self(name: name, kind: .string, summary: summary, required: required)
    }

    static func boolean(_ name: String, _ summary: String, required: Bool = false) -> Self {
        Self(name: name, kind: .boolean, summary: summary, required: required)
    }

    static func integer(_ name: String, _ summary: String, required: Bool = false) -> Self {
        Self(name: name, kind: .integer, summary: summary, required: required)
    }

    static func reference(_ name: String, _ summary: String, required: Bool = true) -> Self {
        Self(name: name, kind: .reference, summary: summary, required: required)
    }

    static func object(_ name: String, _ summary: String, required: Bool = true) -> Self {
        Self(name: name, kind: .object, summary: summary, required: required)
    }

    static func choice(_ name: String, _ summary: String, _ values: [String], required: Bool = true) -> Self {
        Self(name: name, kind: .choice(values), summary: summary, required: required)
    }

    var schema: Property {
        switch kind {
            case .string:
                return .object(["type": .string("string"), "description": .string(summary)])
            case .boolean:
                return .object(["type": .string("boolean"), "description": .string(summary)])
            case .integer:
                return .object(["type": .string("integer"), "description": .string(summary)])
            case .number:
                return .object(["type": .string("number"), "description": .string(summary)])
            case .reference:
                return .object([
                    "type": .string("string"),
                    "format": .string("uri"),
                    "description": .string("\(summary) A scint:// URL, as returned by any Scint tool.")
                ])
            case .object:
                return .object(["type": .string("object"), "description": .string(summary)])
            case .choice(let values):
                return .object([
                    "type": .string("string"),
                    "enum": .array(values.map(Property.string)),
                    "description": .string(summary)
                ])
        }
    }

    static func schema(for parameters: [ToolParameter]) -> Property {
        var schema: [String: Property] = [
            "type": .string("object"),
            "properties": .object(parameters.reduce(into: [String: Property]()) { $0[$1.name] = $1.schema }),
            "additionalProperties": .bool(false)
        ]
        let required = parameters.filter(\.required).map { Property.string($0.name) }
        if !required.isEmpty { schema["required"] = .array(required) }
        return .object(schema)
    }
}
