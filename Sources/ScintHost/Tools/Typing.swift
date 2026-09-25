import Foundation
import ScintRuntime


@MainActor protocol Tool {
    static var method: Method { get }
    static func call(_ arguments: [String: Property], in space: Reference) async throws -> Property
}

struct ToolError: Error { let message: String }

struct Method {
    let name: String
    let title: String
    let description: String
    let schema: Property

    var properties: Property {[
        "name": .string(name),
        "title": .string(title),
        "description": .string(description),
        "schema": schema
    ]}
}
