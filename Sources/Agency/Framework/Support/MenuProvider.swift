import AgencyRuntime
import SwiftUI

enum Surface {
    enum Console {
        enum Processes {}
    }

    struct Content {
        enum Boundary {
            case sheet
            case task
        }
    }

    enum Inspector {
        enum Composition {}
        enum Preview {}
    }

    enum Navigator {
        enum Space {}
        enum Library {}
        enum Notifications {}
    }
}

enum Action {
    static func new(_ ref: Reference, in agency: AgencyModel) {}
    static func show(_ ref: Reference, in agency: AgencyModel) {}
    static func open(_ ref: Reference, in agency: AgencyModel) {}
    static func delete(_ ref: Reference, in agency: AgencyModel) {}
    static func cut(_ ref: Reference, in agency: AgencyModel) {}
    static func copy(_ ref: Reference, in agency: AgencyModel) {}
    static func paste(_ ref: Reference, in agency: AgencyModel) {}
    static func duplicate(_ ref: Reference, in agency: AgencyModel) {}
}

struct Item: Identifiable {
    let id: String
    let label: String
    let image: String
    let action: @MainActor (AgencyModel) -> Void

    init(id: String, label: String, image: String = "", action: @escaping @MainActor (AgencyModel) -> Void) {
        self.id = id
        self.label = label
        self.image = image
        self.action = action
    }
}


