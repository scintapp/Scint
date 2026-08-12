import Foundation


/// Wakes observing spaces when the structure they watch produces a terminal signal.
///
/// The mechanism always fires; it does not inspect the signal or decide whether the
/// work is worth doing. Firing starts a normal intent evaluation, so the harness that
/// wraps the observation makes that call in its own process, with its own context.
enum Observers {
    private nonisolated(unsafe) static var firing: Set<Reference> = []
    private static let lock = NSLock()

    static func install() {
        Composer.shared.onTerminal { structure, _ in
            fire(from: structure)
        }
    }

    /// Spaces whose harness observes, and whose declared target is this structure.
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
        // A cycle of mutual observers would otherwise recurse without bound.
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
