import SwiftUI
import ScintRuntime


struct SectionParams: Hashable, Identifiable {
    let id: AnyHashable
    let name: String
    let header: Bool
    let image: String
    let tint: Color?
    let items: [ItemParams]

    init(id: String? = nil, name: String? = nil, header: Bool? = nil, image: String? = nil, tint: Color? = nil, items: [ItemParams] = []) {
        self.id = id ?? (name ?? "").lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name ?? ""
        self.header = header ?? true
        self.image = image ?? ""
        self.tint = tint
        self.items = items
    }
}
