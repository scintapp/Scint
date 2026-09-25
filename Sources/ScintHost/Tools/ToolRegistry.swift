import Foundation
import ScintRuntime


struct ToolRegistry {
    static var content: ContentTool.Type { ContentTool.self }
    static var interface: InterfaceTool.Type { InterfaceTool.self }
    static var structure: StructureTool.Type { StructureTool.self }
    static var compose: ComposeTool.Type { ComposeTool.self }
    static var dispatch: DispatchTool.Type { DispatchTool.self }
    static var evaluate: EvaluateTool.Type { EvaluateTool.self }
    static var search: SearchTool.Type { SearchTool.self }
    static var context: [Context] { Runtime.shared.resolve() }
    static var tools: [any Tool.Type] { [content, interface, structure, compose] }

    @MainActor static func call(_ name: String, _ arguments: [String: Property], context id: UUID) async throws -> Property? {
        guard tools.contains(where: { $0.method.name == name }) else { return nil }
        guard let space = context.first(where: { $0.space.contextId == id })?.space
        else { throw ToolError(message: "No running context matches this id.") }
        return try await call(name, arguments, in: space)
    }

    @MainActor static func call(_ name: String, _ arguments: [String: Property], in space: Reference) async throws -> Property? {
        guard let tool = tools.first(where: { $0.method.name == name }) else { return nil }
        return try await tool.call(arguments, in: space)
    }
}

extension Dictionary where Key == String, Value == Property {
    func link(_ name: String) throws -> Reference? {
        guard let value = self[name] else { return nil }
        guard let text = value.string, let ref = Reference.Link.reference(in: text)
                else { throw ToolError(message: "\(name) must be a scint:// link.") }
        return ref
    }

    func required(_ name: String) throws -> Reference {
        guard let ref = try link(name) else { throw ToolError(message: "\(name) is required.") }
        return ref
    }

    func text(_ name: String) throws -> String {
        guard let text = self[name]?.string, !text.isEmpty else { throw ToolError(message: "\(name) is required.") }
        return text
    }

    func choice<Choice: RawRepresentable & CaseIterable>(_ name: String, _ type: Choice.Type) throws -> Choice where Choice.RawValue == String {
        guard let value = self[name]?.string, let choice = Choice(rawValue: value)
                else { throw ToolError(message: "\(name) must be one of: \(type.allCases.map(\.rawValue).joined(separator: ", ")).") }
        return choice
    }
}
