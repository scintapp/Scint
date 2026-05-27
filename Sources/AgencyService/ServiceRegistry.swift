import AgencyRuntime
import Foundation
import Darwin
import Combine


final class ServiceRegistry: @unchecked Sendable {
    static let shared = ServiceRegistry()

    private let queue = DispatchQueue(label: "com.kaechle.agencyd.registry", attributes: .concurrent)
    private var definitions: [String: ServiceDefinition] = [:]
    private var activePIDs: [String: pid_t] = [:]
    private var pidToService: [pid_t: String] = [:]

    private init() {}

    func register(_ def: ServiceDefinition) {
        queue.async(flags: .barrier) {
            self.definitions[def.id] = def
        }
    }

    func unregister(_ id: String) -> Bool {
        var found = false
        queue.sync(flags: .barrier) {
            found = definitions.removeValue(forKey: id) != nil
            if let pid = activePIDs.removeValue(forKey: id) {
                pidToService.removeValue(forKey: pid)
            }
        }
        return found
    }

    func definition(for id: String) -> ServiceDefinition? {
        queue.sync { definitions[id] }
    }

    func all() -> [ServiceDefinition] {
        queue.sync { definitions.values.sorted { $0.id < $1.id } }
    }

    func setActivePID(_ pid: pid_t, for serviceID: String) {
        queue.async(flags: .barrier) {
            if let old = self.activePIDs[serviceID] {
                self.pidToService.removeValue(forKey: old)
            }
            self.activePIDs[serviceID] = pid
            self.pidToService[pid] = serviceID
        }
    }

    func clearPID(for serviceID: String) {
        queue.async(flags: .barrier) {
            if let pid = self.activePIDs.removeValue(forKey: serviceID) {
                self.pidToService.removeValue(forKey: pid)
            }
        }
    }

    func activePID(for serviceID: String) -> pid_t? {
        queue.sync { activePIDs[serviceID] }
    }

    func serviceID(for pid: pid_t) -> String? {
        queue.sync { pidToService[pid] }
    }
}

public enum ServicePolicy: String, Sendable {
    case never
    case onFailure
    case always

    public static func from(_ string: String?) -> ServicePolicy {
        ServicePolicy(rawValue: string ?? "") ?? .never
    }
}

public struct ServiceDefinition: Sendable {
    public let id: String
    public let command: String
    public let arguments: [String]
    public let policy: ServicePolicy

    public init?(params: [String: Any]) {
        guard
            let id = params["id"] as? String, !id.isEmpty,
            let command = params["command"] as? String, !command.isEmpty
        else { return nil }

        self.id = id
        self.command = command
        self.arguments = (params["arguments"] as? [String]) ?? []
        self.policy = ServicePolicy.from(params["policy"] as? String)
    }

    public func params() -> [String: Any] {
        return [
            "id": id,
            "command": command,
            "arguments": arguments,
            "policy": policy.rawValue
        ]
    }
}

public struct Handler: Codable & Sendable {
    public var format: Format

    public enum Format: String, Codable, Sendable {
        case lines
        case events
    }

    public init(_ format: Format = .events) { self.format = format }

    public func handle(_ chunk: String) -> [Event] {
        switch format {
        case .lines:
            return chunk
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .filter { !$0.isEmpty }
                .map { line in
                    .provider(Properties(.object([
                        "type": .string("message"),
                        "text": .string(line)
                    ])))
                }

        case .events:
            guard let properties = Properties.provider(chunk) else {
                return [.provider(Properties(.object([
                    "type": .string("raw"),
                    "text": .string(chunk)
                ])))]
            }
            return [.provider(properties)]
        }
    }
}

