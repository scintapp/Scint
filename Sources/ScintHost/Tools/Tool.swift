import Foundation


/// What a tool call produced.
struct ToolResult: Sendable {
    let text: String
    let isError: Bool

    static func ok(_ text: String) -> Self { Self(text: text, isError: false) }
    static func failure(_ text: String) -> Self { Self(text: text, isError: true) }
}

/// One parameter of a tool.
///
/// A tool declares what it takes; the JSON Schema is derived from that in one place. Every tool
/// used to hand-write its own nested `Property` dictionaries — forty lines of `.object([...])` per
/// operation to say "a required string and an optional boolean".
struct ToolParameter: Sendable {
    enum Kind: Sendable {
        case string
        case boolean
        case integer
        case number
        /// A `scint://` URL naming a runtime object.
        case reference
        /// A free-form object, for arguments whose shape a tool reports rather than declares.
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

    /// The object schema for a set of parameters.
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

protocol Tool: Sendable {
    var namespace: ToolNamespace { get }
    var operation: String { get }
    var name: String { get }
    var title: String { get }
    var summary: String { get }

    var subject: Reference? { get }

    var parameters: [ToolParameter] { get }
    var inputSchema: Property { get }

    func call(_ arguments: Properties) async -> ToolResult
}

extension Tool {
    var name: String { namespace.qualified(operation) }
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
