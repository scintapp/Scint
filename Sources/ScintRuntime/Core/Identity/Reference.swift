import Foundation


typealias ActivityId = UUID
typealias ContextId = UUID
typealias DescriptorId = UUID
typealias StorageId = UUID
typealias TypeId = UUID

struct Reference: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    let typeId: TypeId
    let contextId: ContextId
    let descriptorId: DescriptorId
    let storageId: StorageId

    enum Link {
        static let scheme = "scint"

        static func url(for ref: Reference) -> URL? {
            guard let host = host(for: ref) else { return nil }
            return URL(string: "\(scheme)://\(host)/\(ref.descriptorId.uuidString.lowercased())")
        }

        static func markdown(for ref: Reference, name: String? = nil) -> String? {
            guard let url = url(for: ref) else { return nil }
            return "[\(label(name ?? Catalog.shared.get(ref)?.name ?? "Reference"))](\(url.absoluteString))"
        }

        static func isReference(_ string: String) -> Bool {
            URL(string: string)?.scheme?.lowercased() == scheme
        }

        static func reference(in string: String) -> Reference? {
            guard let url = URL(string: string) else { return nil }
            return reference(in: url)
        }

        static func reference(in url: URL) -> Reference? {
            guard url.scheme?.lowercased() == scheme else { return nil }

            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let query = components.queryItems?.first(where: { $0.name == "ref" })?.value,
               let found = resolve(query) {
                return found
            }

            return url.pathComponents.last { $0 != "/" }.flatMap(resolve)
        }

        static func resolve(_ id: String) -> Reference? {
            guard let descriptorId = UUID(uuidString: id) else { return nil }
            return Catalog.shared.get(descriptorId)
        }

        static func host(for ref: Reference) -> String? {
            guard let type = ref.type else { return nil }
            return String(describing: type).lowercased()
        }

        private static func label(_ name: String) -> String {
            let cleaned = name
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return cleaned.isEmpty ? "Reference" : cleaned
        }
    }

    init(_ type: Resolvable.Type, id: UUID = .init(), descriptor: DescriptorId? = nil, context: ContextId? = nil, storage: StorageId? = nil) {
        self.id = id
        self.typeId = .typeId(type.self)
        self.descriptorId = descriptor ?? id
        self.storageId = storage ?? id
        self.contextId = context ?? id
    }

    init(id: UUID, typeId: UUID, descriptorId: DescriptorId? = nil, contextId: ContextId? = nil, storageId: StorageId? = nil) {
        self.id = id
        self.typeId = typeId
        self.descriptorId = descriptorId ?? id
        self.contextId = contextId ?? id
        self.storageId = storageId ?? id
    }

    var type: Resolvable.Type? { Runtime.shared.registry.resolve(self) }
    var context: Composition? { Composer.shared.compose(self) }
    var descriptor: Descriptor { Runtime.shared.get(self) }
    var handle: String { String(storageId.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8)) }

    func delete() async throws {
        switch type {
            case is any Structural.Type: try await Workspaces.shared.delete(self)
            case is any Malleable.Type, is any Functional.Type: try await Library.shared.delete(self)
            default: throw RuntimeError.error("No store found.")
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(typeId)
        hasher.combine(descriptorId)
    }

    static func == (lhs: Reference, rhs: Reference) -> Bool {
        lhs.typeId == rhs.typeId
        && lhs.descriptorId == rhs.descriptorId
        && lhs.id == rhs.id
    }
}
