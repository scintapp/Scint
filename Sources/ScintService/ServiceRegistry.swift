import Foundation
import ScintRuntime


enum ServicePolicy: String, Sendable {
    case never, failure, always

    static func from(_ string: String?) -> ServicePolicy {
        ServicePolicy(rawValue: string ?? "") ?? .never
    }
}

struct ServiceHandler: Codable & Sendable {
    var format: Format

    enum Format: String, Codable, Sendable { case lines, events }

    init(_ format: Format = .events) { self.format = format }

    func handle(_ chunk: String) -> [Value] {
        switch format {
            case .lines:
                return chunk
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
                    .filter { !$0.isEmpty }
                    .map { line in
                            .collection([
                                "type": .property("message"),
                                "text": .property(.string(line))
                            ])
                    }

            case .events:
                return [.property(.string(chunk))]
        }
    }
}

struct ServiceDefinition: Sendable {
    let id: String
    let command: String
    let arguments: [String]
    let policy: ServicePolicy

    init?(params: [String: Any]) {
        guard
            let id = params["id"] as? String, !id.isEmpty,
            let command = params["command"] as? String, !command.isEmpty
                else { return nil }

        self.id = id
        self.command = command
        self.arguments = (params["arguments"] as? [String]) ?? []
        self.policy = ServicePolicy.from(params["policy"] as? String)
    }

    func parameters() -> [String: Any] {
        return [
            "id": id,
            "command": command,
            "arguments": arguments,
            "policy": policy.rawValue
        ]
    }
}

final class ServiceRegistry: @unchecked Sendable {
    static let shared = ServiceRegistry()
    private var definitions: [String: ServiceDefinition] = [:]
    private var activePIDs: [String: pid_t] = [:]
    private var pidToService: [pid_t: String] = [:]
    private let queue = DispatchQueue(label: "com.kaechle.scintd.registry", attributes: .concurrent)

    func register(_ def: ServiceDefinition) { queue.async(flags: .barrier) { self.definitions[def.id] = def } }

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

