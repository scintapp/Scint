import Foundation


struct Artifact: Functional {
    let ref: Reference
    let handler: Handler

    enum Handler: Codable, Sendable, Equatable {
        case app(URL?)
        case bookmark(URL?)
        case directory(URL?)
        case executable(URL?)
        case file(URL?)
        case image(URL?)
        case script(URL?)
        case skill(URL?)

        var url: URL? {
            switch self {
                case .app(let u), .bookmark(let u), .executable(let u): Self.normalize(u)
                case .directory(let u), .file(let u): Self.normalize(u)
                case .image(let u), .script(let u), .skill(let u): Self.normalize(u)
            }
        }

        var type: String {
            switch self {
                case .app: "app"
                case .bookmark: "bookmark"
                case .directory: "directory"
                case .executable: "executable"
                case .file: "file"
                case .image: "image"
                case .script: "script"
                case .skill: "skill"
            }
        }

        var name: String {
            url?.lastPathComponent ?? ""
        }

        var directory: Bool {
            if case .directory = self { true }
            else { false }
        }

        var children: [Handler] {
            guard let url, directory,
                  let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [])
            else { return [] }
            return urls.map { Self.classify($0) }.sorted {
                ($0.url?.path ?? "").localizedCaseInsensitiveCompare($1.url?.path ?? "") == .orderedAscending
            }
        }

        var resolvable: Bool {
            guard let url, url.isFileURL else { return false }
            return FileManager.default.isExecutableFile(atPath: url.path)
        }

        var executable: String? {
            guard resolvable else { return nil }
            return url?.path(percentEncoded: false)
        }

        static func classify(_ url: URL?) -> Handler {
            guard let url else { return .file(nil) }
            guard url.isFileURL else { return .bookmark(url) }

            let resolved = normalize(url)
            let ext = resolved.pathExtension.lowercased()
            if ext == "app" { return .app(resolved) }

            var isDir: ObjCBool = false

            if FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir), isDir.boolValue {
                return .directory(resolved)
            }

            if skill(resolved) { return .skill(resolved) }
            if image(resolved) { return .image(resolved) }
            if script(resolved) { return .script(resolved) }

            if FileManager.default.isExecutableFile(atPath: resolved.path) {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir)
                if !isDir.boolValue { return .executable(resolved) }
            }

            return .file(resolved)
        }

        private static func image(_ url: URL) -> Bool {
            let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp", "svg"]
            return imageExts.contains(url.pathExtension.lowercased())
        }

        private static func script(_ url: URL) -> Bool {
            guard let handle = try? FileHandle(forReadingFrom: url)
            else { return false }
            defer { try? handle.close() }
            let prefix = (try? handle.read(upToCount: 128)) ?? nil
            guard let data = prefix, !data.isEmpty
            else { return false }
            guard let line = String(data: data, encoding: .utf8)?.split(whereSeparator: \.isNewline).first
            else { return false }
            return line.hasPrefix("#!")
        }

        private static func skill(_ url: URL) -> Bool {
            url.lastPathComponent == "SKILL.md"
        }

        private static func normalize(_ url: URL?) -> URL? {
            guard let url else { return nil }
            guard url.isFileURL else { return url }
            return normalize(url)
        }

        private static func normalize(_ url: URL) -> URL {
            url.standardizedFileURL
        }
    }

    init(_ ref: Reference, handler: Handler) {
        self.ref = ref
        self.handler = handler
    }

    var rendered: String {
        let url = handler.url!
        return url.isFileURL ? url.path(percentEncoded: false) : url.absoluteString
    }

    func matches(_ other: Artifact) -> Bool { handler == other.handler }

    @discardableResult
    static func new(_ name: String, _ url: URL) -> Reference {
        let instance = Artifact(.init(Self.self), handler: Artifact.Handler.classify(url))
        return register(name, instance, tags: [instance.handler.type])
    }
}

extension Artifact.Handler {
    private enum CodingKeys: String, CodingKey, CaseIterable { case app, bookmark, directory, executable, file, image, script, skill }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let key = try c.tag()
        let url = try c.decodeIfPresent(URL.self, forKey: key)
        switch key {
            case .app: self = .app(url)
            case .bookmark: self = .bookmark(url)
            case .directory: self = .directory(url)
            case .executable: self = .executable(url)
            case .file: self = .file(url)
            case .image: self = .image(url)
            case .script: self = .script(url)
            case .skill: self = .skill(url)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        guard let key = CodingKeys(rawValue: type) else { return }
        try c.encode(url, forKey: key)
    }
}
