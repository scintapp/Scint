import Foundation


actor Persistence {
    static let shared = Persistence()

    func read<T: Storable>(_ type: T.Type, at url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func write<T: Storable>(_ PersistedObject: PersistableObject<T>) throws {
        try FileManager.default.createDirectory(
            at: PersistedObject.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PersistedObject.encoder.encode(PersistedObject.value)
        try data.write(to: PersistedObject.url, options: .atomic)
    }

    func delete(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func files(in directory: URL, ext: String = "json") throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { ext.isEmpty || $0.pathExtension == ext }
    }
}
