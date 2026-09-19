import Foundation


enum ScintHostOperation: Sendable, Equatable {
    case listTools(cursor: String?)
    case callTool(name: String, arguments: [String: Property])
    case listResources(cursor: String?)
    case readResource(uri: String)
}

enum ScintHostBridgeError: Error, Sendable, Equatable {
    case contextNotFound(UUID)
    case invalidArguments(String)
    case resourceNotFound(String)
    case toolNotFound(String)
}

protocol ScintHostBridge: Sendable {
    func perform(_ request: ScintHostRequest) async throws -> [String: Property]
}

struct ScintHostRequest: Sendable, Equatable {
    let context: UUID
    let operation: ScintHostOperation
}
