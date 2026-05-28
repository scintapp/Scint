import SwiftUI
import AgencyRuntime


extension Composition.State {
    var consoleName: String {
        switch self {
        case .idle: "Idle"
        case .active: "Active"
        case .running: "Running"
        case .blocked: "Blocked"
        case .failed: "Failed"
        }
    }

    var consoleTint: Color {
        switch self {
        case .idle: Design.Tint.ready
        case .active: Design.Tint.active
        case .running: Design.Tint.running
        case .blocked: Design.Tint.blocked
        case .failed: Design.Tint.failed
        }
    }
}


enum ConsoleMonitorMap {
    static func model(filter: ConsoleMonitorFilter = .all) -> ConsoleMonitorModel {
        let compositions = Runtime.shared.context()
            .filter { $0.origin.type is Space.Type }
            .sorted(by: sort)

        return ConsoleMonitorModel(filter: filter, compositions: compositions)
    }

    private static func sort(_ lhs: Composition, _ rhs: Composition) -> Bool {
        if rank(lhs.state) != rank(rhs.state) {
            return rank(lhs.state) > rank(rhs.state)
        }
        return lhs.origin.name.localizedCaseInsensitiveCompare(rhs.origin.name) == .orderedAscending
    }

    private static func rank(_ state: Composition.State) -> Int {
        switch state {
        case .failed: 5
        case .blocked: 4
        case .running: 3
        case .active: 2
        case .idle: 1
        }
    }
}


struct ProcessesMap: Mapper {
    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
        .init(
            selected: { $0.ref.map { agency.session.selected($0) } ?? false },
            onSelect: { $0.ref.map { agency.select($0) } }
        )
    }

    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
        let compositions = Runtime.shared.context()
            .filter { $0.origin.type is Space.Type && $0.state != .idle }

        let items: [ItemParams] = compositions.map { c in
            return .init(
                ref: c.origin,
                origin: c.origin,
                name: c.origin.name,
                description: c.origin.description,
                tags: [],
                badges: [.init(icon: "circle.fill", label: c.state.consoleName, count: 0, tint: c.state.consoleTint)],
                items: [.init(
                    name: Transcript.with(c.transcript, { $0.name }) ?? "",
                    description: Transcript.with(c.transcript, { $0.content.last }) ?? ""
                )]
            )
        }

        return .init(
            nesting: .flat,
            sections: [.init(
                id: "processes",
                name: "Processes",
                layout: panel.layout,
                footnote: "\(compositions.count) tracked",
                items: items)
            ],
            columns: [
                .init(title: "Process", width: 320, value: .name),
                .init(title: "Transcription", value: .child(0)),
                .init(title: "Intents", value: .tags),
                .init(title: "State", width: 100, alignment: .trailing, value: .badge),
            ]
        )
    }
}
