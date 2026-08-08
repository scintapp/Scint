import Foundation


final class Library: Sendable {
    static let shared = Library()
    private let content: Content = .init()
    private let interfaces: Interfaces = .init()

    func store(for ref: Reference) -> (any Bounding)? {
        switch ref.type {
        case is any Malleable.Type: return content
        case is any Functional.Type: return interfaces
        default: return nil
        }
    }

    func load() async throws {
        let settings = Runtime.shared.settings.persistence

        func read(_ dir: URL) async throws -> [StorableObject] {
            var out: [StorableObject] = []
            for url in try await Persistence.shared.files(in: dir) {
                out.append(try await Persistence.shared.read(StorableObject.self, at: url))
            }
            return out
        }

        interfaces.decode(try await read(settings.interfaceDirectory(for: Artifact.self)))
        interfaces.decode(try await read(settings.interfaceDirectory(for: Command.self)))
        interfaces.decode(try await read(settings.interfaceDirectory(for: Harness.self)))
        content.decode(try await read(settings.componentDirectory(for: Scene.self)))
        content.decode(try await read(settings.componentDirectory(for: Transcript.self)))
    }

    func save() async throws { try await write(try interfaces.records() + content.records()) }

    func save(_ ref: Reference) async {
        do { try await save([ref]) }
        catch { print("Save failed for \(ref.id): \(error)") }
    }

    func save(_ refs: Set<Reference>) async throws {
        let records = try refs.compactMap { ref in try store(for: ref)?.record(for: ref) }
        try await write(records)
    }

    func write(_ records: [StorableObject]) async throws {
        for record in records {
            let url = Runtime.shared.settings.persistence.libraryPath(for: record.value.ref)
            try await Persistence.shared.write(PersistedObject(url: url, value: record))
        }
    }

    func delete(_ ref: Reference) async throws {
        let url = Runtime.shared.settings.persistence.libraryPath(for: ref)
        Catalog.shared.delete(ref)
        for (_, space) in Runtime.shared.all(as: Space.self) { space.remove(ref) }
        for (_, workspace) in Runtime.shared.all(as: Workspace.self) { workspace.remove(ref) }
        store(for: ref)?.remove(ref)
        try await Persistence.shared.delete(at: url)
        try await Workspaces.shared.save()
    }
}
