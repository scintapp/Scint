import Foundation


enum ScintMCPOperation: Sendable, Equatable {
    case listTools(cursor: String?)
    case callTool(name: String, arguments: [String: Property])
    case listResources(cursor: String?)
    case readResource(uri: String)
}

struct ScintMCPBridgeRequest: Sendable, Equatable {
    let context: UUID
    let operation: ScintMCPOperation
}

protocol ScintMCPBridge: Sendable {
    func perform(_ request: ScintMCPBridgeRequest) async throws -> [String: Property]
}

enum ScintMCPBridgeError: Error, Sendable, Equatable {
    case contextNotFound(UUID)
    case invalidArguments(String)
    case resourceNotFound(String)
    case toolNotFound(String)
}
