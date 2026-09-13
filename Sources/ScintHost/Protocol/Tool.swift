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
}

enum Tools {
    static let prefix = "scint"

    static func name(_ segments: String...) -> String {
        ([prefix] + segments).joined(separator: ".")
    }


}

protocol Tool: Sendable {
    var name: String { get }
    var title: String { get }
    var summary: String { get }
    var subject: Reference? { get }
    var inputSchema: Property { get }

    func call(_ arguments: Properties) async -> ToolResult
}

extension Tool {
    var subject: Reference? { nil }
    var inputSchema: Property { .schema([:]) }

    var definition: Property {
        var value: Property = [
            "name": .string(name),
            "title": .string(title),
            "description": .string(summary),
            "inputSchema": inputSchema
        ]
        if let subject, let url = Reference.Link.url(for: subject) {
            value["_meta"] = ["com.kaechle.scint/address": .string(url.absoluteString)]
        }
        return value
    }
}

extension Property {
    /// An argument that names something by address.
    ///
    /// The trailing sentence is identical everywhere on purpose, so a model learns the format once
    /// instead of inferring it from each tool's wording. It is the one piece of schema worth a
    /// helper; everything else reads better written out.
    static func address(_ summary: String) -> Property {
        [
            "type": "string",
            "format": "uri",
            "description": "\(summary) A scint:// URL, as returned by any Scint tool."
        ]
    }
}

struct ToolResult: Sendable {
    let text: String
    let isError: Bool

    static func ok(_ text: String) -> Self { Self(text: text, isError: false) }
    static func failure(_ text: String) -> Self { Self(text: text, isError: true) }
}
