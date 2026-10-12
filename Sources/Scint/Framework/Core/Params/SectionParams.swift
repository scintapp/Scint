import SwiftUI
import ScintRuntime


struct SectionParams: Hashable, Identifiable {
    let id: AnyHashable
    let name: String
    let description: String
    let header: Bool
    let image: String
    let tint: Color?
    let layout: Layout?
    var items: [ItemParams]
    let sections: [SectionParams]

    init(id: String? = nil, name: String? = nil, description: String? = nil, header: Bool? = nil, image: String? = nil, tint: Color? = nil, layout: Layout? = nil, items: [ItemParams] = [], sections: [SectionParams] = []) {
        self.id = id ?? (name ?? "").lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name ?? ""
        self.description = description ?? ""
        self.header = header ?? true
        self.image = image ?? ""
        self.tint = tint
        self.layout = layout
        self.items = items
        self.sections = sections
    }
}
