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

/// The family of runtime object a tool acts on, and the namespace it is called under.
///
/// Not a naming convention: each case is bound to one of the runtime's own protocols, so a
/// namespace is derived from what a tool operates on rather than typed into its name. A tool
/// cannot be named into a family its subject does not belong to, and the tool surface stays a
/// mirror of the runtime instead of a parallel vocabulary someone has to keep in their head.
///
/// The names are the families as they are spoken about, not as the protocols are spelled. That
/// also keeps them out of the way of `ReferenceURL`, whose host is the concrete *type* — so
/// `scint://material/<id>` is a Material and `scint.content.*` is the family holding Material and
/// Transcript, with no word doing both jobs.
enum ToolNamespace: String, CaseIterable, Sendable {
    /// `Malleable` — Material, Transcript.
    case content
    /// `Functional` — Artifact, Command, Harness.
    case interfaces
    /// `Structural` — Bridge, Closure, Space, Workspace.
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

    /// The namespace a tool name is in, so a name can be read as well as written.
    static func of(name: String) -> ToolNamespace? {
        let parts = name.split(separator: ".")
        guard parts.count >= 2, parts[0] == prefix else { return nil }
        return ToolNamespace(rawValue: String(parts[1]))
    }

    static let prefix = "scint"

    func qualified(_ operation: String) -> String { "\(Self.prefix).\(rawValue).\(operation)" }
}

/// Something the MCP server can list and call.
///
/// This replaces `Facet`, which was a struct of closures plus one adapter extension per tool type
/// — a protocol-shaped hole filled by hand. A tool now says what it is and answers when called.
protocol Tool: Sendable {
    /// The family this tool acts on. Determines the namespace half of its name.
    var namespace: ToolNamespace { get }
    /// What this tool does, within its namespace.
    var operation: String { get }

    var name: String { get }
    var title: String { get }
    var summary: String { get }

    /// The runtime object this tool *is*, when it is one.
    ///
    /// An interface and an artifact are objects; a content verb operating over many documents is
    /// not, and has none. When present, the tool's address is published alongside its definition —
    /// and because both are keyed on the descriptor id, an address found in a document resolves to
    /// the tool that acts on it without anyone having to be told the rule twice.
    var subject: Reference? { get }

    /// What the tool takes. Leave empty and override `inputSchema` when the shape is derived at
    /// runtime rather than declared.
    var parameters: [ToolParameter] { get }
    var inputSchema: Property { get }

    func call(_ arguments: Properties) async -> ToolResult
}

extension Tool {
    var name: String { namespace.qualified(operation) }
    var subject: Reference? { nil }
    var parameters: [ToolParameter] { [] }
    var inputSchema: Property { ToolParameter.schema(for: parameters) }

    /// The MCP tool definition, assembled once for every tool.
    var definition: Property {
        var value: [String: Property] = [
            "name": .string(name),
            "title": .string(title),
            "description": .string(summary),
            "inputSchema": inputSchema
        ]
        if let subject, let url = ReferenceURL.url(for: subject) {
            value["_meta"] = .object(["com.kaechle.scint/address": .string(url.absoluteString)])
        }
        return .object(value)
    }
}

/// Every tool available in a space.
enum Tools {
    /// Providers, by the family they serve. Adding a kind of tool means adding a line here — it
    /// used to mean editing the type that erased them.
    ///
    /// `CatalogTool` supplies `list` and `describe` to every family; the rest is what differs.
    /// Interfaces keep a tool per object as well, so a client gets a real schema for each one
    /// rather than an opaque `call(interface:arguments:)`.
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

    /// The namespaces that actually have tools, for reporting an unknown name usefully.
    static var populated: [ToolNamespace] { ToolNamespace.allCases.filter { providers[$0]?.isEmpty == false } }
}
