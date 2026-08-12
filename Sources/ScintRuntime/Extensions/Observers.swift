import Foundation


enum Observers {
    private nonisolated(unsafe) static var firing: Set<Reference> = []
    private static let lock = NSLock()

    static func install() {
        Composer.shared.onTerminal { structure, _ in
            fire(from: structure)
        }
    }

    static func watchers(of target: Reference) -> [Reference] {
        Runtime.shared.all(as: Space.self).compactMap { ref, space in
            guard ref != target else { return nil }
            guard let harness = space.harness,
                  Harness.with(harness, { $0.intent }) == .observe
            else { return nil }
            guard case .reference(let watched)? = space.config["target"], watched == target
            else { return nil }
            return ref
        }
    }

    private static func fire(from structure: Reference) {
        let claimed: [Reference] = lock.withLock {
            guard !firing.contains(structure) else { return [] }
            firing.insert(structure)
            return watchers(of: structure).filter { !firing.contains($0) }
        }
        defer { lock.withLock { let _ = firing.remove(structure) } }

        for observer in claimed {
            _ = Runtime.shared.start(observer, config: [
                "trigger": .string(structure.descriptor.name)
            ])
        }
    }
}
