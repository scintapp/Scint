import SwiftUI
import ScintRuntime


struct ActionParams: Identifiable {
    let id: String
    let label: String
    let image: String
    let keywords: [String]
    let role: ButtonRole?
    let enabled: @MainActor (Model) -> Bool
    let action: @MainActor (Model) -> Void

    init(
        id: String,
        label: String,
        image: String = "",
        keywords: [String] = [],
        role: ButtonRole? = nil,
        enabled: @escaping @MainActor (Model) -> Bool = { _ in true },
        action: @escaping @MainActor (Model) -> Void
    ) {
        self.id = id
        self.label = label
        self.image = image
        self.keywords = keywords
        self.role = role
        self.enabled = enabled
        self.action = action
    }
}
