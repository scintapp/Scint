import Foundation


public struct SettingsKeys: Sendable {
    let name: String
    let persistence: Persistence = .init()

    public struct Persistence: Sendable {
        var data: (String, String) = ("XDG_DATA_HOME", ".local/share")
        var config: (String, String) = ("XDG_CONFIG_HOME", ".config")
    }
}

public struct Settings: Sendable {
    let keys: SettingsKeys
    public var persistence: PersistenceSettings

    public init(name: String = "Scint") {
        self.keys = SettingsKeys(name: name)
        self.persistence = PersistenceSettings(keys: keys)
    }
}

public struct PersistenceSettings: Sendable {
    let keys: SettingsKeys
    var lastSpaceKey: String { "\(keys.name).lastSpaceId" }
    var config: URL { path(keys.persistence.config).appendingPathComponent(keys.name, isDirectory: true) }
    var data: URL { path(keys.persistence.data).appendingPathComponent(keys.name, isDirectory: true) }
    var library: URL { data.appendingPathComponent("library", isDirectory: true) }
    var transcripts: URL { data.appendingPathComponent("transcripts", isDirectory: true) }
    var workspaces: URL { data.appendingPathComponent("workspaces", isDirectory: true) }

    var lastWorkspaceId: UUID? {
        get {
            guard let string = UserDefaults.standard.string(forKey: lastSpaceKey) else { return nil }
            return UUID(uuidString: string)
        }
        nonmutating set {
            if let id = newValue { UserDefaults.standard.set(id.uuidString, forKey: lastSpaceKey) }
            else { UserDefaults.standard.removeObject(forKey: lastSpaceKey) }
        }
    }

    private func typePath(for ref: Reference) -> String {
        let name = switch ref.type {
            case is Sheet.Type: "sheets"
            case is Transcript.Type: "transcripts"
            case is Artifact.Type: "artifacts"
            case is Command.Type: "commands"
            case is Harness.Type: "harnesses"
            default: Runtime.shared.registry.entriesByTypeId[ref.typeId]
                    .map { String(describing: $0.type).lowercased() }
                ?? "unknown"
        }
        return name.hasSuffix("s") ? name : "\(name)s"
    }

    private func instancePath(for ref: Reference) -> String {
        ref.storageId.uuidString.lowercased()
    }

    func path(_ key: (String, String)) -> URL {
        if let xdg = ProcessInfo.processInfo.environment[key.0], !xdg.isEmpty {
            return URL(fileURLWithPath: xdg, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appending(path: key.1)
    }

    func libraryPath(for ref: Reference) -> URL {
        library
            .appendingPathComponent(typePath(for: ref))
            .appendingPathComponent(instancePath(for: ref))
            .appendingPathExtension("json")
    }

    func componentPath<T: Resolvable>(for type: T.Type, name: String) -> URL {
        library
            .appendingPathComponent(directory(for: type), isDirectory: true)
            .appendingPathComponent(slug(name))
            .appendingPathExtension("json")
    }

    func interfacePath<T: Resolvable>(for type: T.Type, name: String) -> URL {
        library
            .appendingPathComponent(directory(for: type), isDirectory: true)
            .appendingPathComponent(slug(name))
            .appendingPathExtension("json")
    }

    func componentDirectory<T: Resolvable>(for type: T.Type) -> URL {
        library.appendingPathComponent(directory(for: type), isDirectory: true)
    }

    func interfaceDirectory<T: Resolvable>(for type: T.Type) -> URL {
        library.appendingPathComponent(directory(for: type), isDirectory: true)
    }

    func spacesPath(_ id: UUID) -> URL {
        workspaces.appendingPathComponent("\(id.uuidString).json")
    }


    private func directory<T: Resolvable>(for type: T.Type) -> String {
        switch type {
            case is Sheet.Type: return "sheets"
            case is Artifact.Type: return "artifacts"
            case is Command.Type: return "commands"
            case is Harness.Type: return "harnesses"
            default: return String(describing: type).lowercased() + "s"
        }
    }

    private func slug(_ name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
