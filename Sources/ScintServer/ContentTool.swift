import Foundation


/// Retrieval for materials the serialization lists but does not expand. The document
/// carries structure and current state; this carries the bodies, on request.
///
/// Handles are a truncated `storageId` — short enough to read inside a document,
/// stable across renames. Resolution matches by prefix and requires a unique hit,
/// so a collision fails loudly instead of returning the wrong sheet.
struct ContentTool: Sendable {
    static let toolName = "Scint.content.load"

    let origin: Reference

    static let handleLength = 8

    static func handle(for ref: Reference) -> String {
        String(ref.storageId.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(handleLength))
    }

    static func manifest(in origin: Reference) -> [(handle: String, ref: Reference)] {
        guard let closure = Space.with(origin, { $0.closure }) ?? Workspace.with(origin, { $0.closure })
        else { return [] }
        return (Closure.with(closure, { $0.materials }) ?? [])
            .filter { !$0.descriptor.tags.contains("input") }
            .map { (handle(for: $0), $0) }
    }

    static func all(in origin: Reference) -> [ContentTool] {
        manifest(in: origin).isEmpty ? [] : [ContentTool(origin: origin)]
    }

    static func find(_ name: String, in origin: Reference) -> ContentTool? {
        guard name == toolName else { return nil }
        return all(in: origin).first
    }

    private var inputSchema: Property {
        .object([
            "type": .string("object"),
            "properties": .object([
                "id": .object([
                    "type": .string("string"),
                    "description": .string("The bracketed handle shown beside a sheet in the Content section.")
                ])
            ]),
            "required": .array([.string("id")]),
            "additionalProperties": .bool(false)
        ])
    }

    var definition: Property {
        return .object([
            "name": .string(Self.toolName),
            "title": .string("Load sheet"),
            "description": .string("Read the full body of a sheet, using a handle from the Content section."),
            "inputSchema": inputSchema
        ])
    }

    func call(_ arguments: Properties) -> ServerTool.Invocation {
        guard let supplied = arguments["id"]?.string, !supplied.isEmpty else {
            return .init(text: "A sheet handle is required.", isError: true)
        }

        let wanted = supplied
            .trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
            .lowercased()
            .replacingOccurrences(of: "-", with: "")

        let entries = Self.manifest(in: origin)
        let matches = entries.filter { $0.handle.hasPrefix(wanted) || wanted.hasPrefix($0.handle) }

        guard !matches.isEmpty else {
            let available = entries.map { "\($0.ref.descriptor.name) [\($0.handle)]" }.joined(separator: ", ")
            return .init(
                text: available.isEmpty
                    ? "This space has no sheets."
                    : "No sheet matches \(supplied). Available: \(available)",
                isError: true
            )
        }
        guard matches.count == 1, let match = matches.first else {
            let ambiguous = matches.map { "[\($0.handle)]" }.joined(separator: ", ")
            return .init(text: "\(supplied) matches more than one sheet: \(ambiguous)", isError: true)
        }

        let body = Runtime.shared.rendered(match.ref).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            return .init(text: "\(match.ref.descriptor.name) is empty.", isError: false)
        }
        return .init(text: "# \(match.ref.descriptor.name)\n\n\(body)", isError: false)
    }
}
