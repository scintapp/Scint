import SwiftUI
import AgencyRuntime


struct CompositionMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures {
        .init(
            onSelect: { item in
                guard let ref = item.ref else { return }
                agency.select(ref, from: item.origin)
            }
        )
    }

    static func params(_ agency: AgencyModel, _ frame: any Panel) -> Params {
        let origin = agency.session.boundary ?? agency.session.space

        guard let components = Space.with(origin, { Closure.with($0.closure, { $0.components }) }) ?? [] else {
            return Params()
        }

        let closures: [ItemParams] = components
            .filter { $0.type is Control.Type }
            .compactMap { control in
                guard let name = Control.with(control, { $0.name }) else { return nil }
                return .init(
                    ref: control,
                    origin: origin,
                    name: name,
                    image: "switch.2",
                    tint: Design.Tint.control
                )
            }

        let serviceItems: [ItemParams] = components
            .filter { $0.type is Service.Type }
            .compactMap { r in
                guard let name = Service.with(r, { $0.name }) else { return nil }
                return .init(
                    ref: r,
                    origin: origin,
                    name: name,
                    image: "arrow.2.squarepath",
                    tint: Design.Tint.service
                )
            }

        return Params(
            sections: [
                .init(
                    id: "automation",
                    name: "Automation",
                    layout: .group,
                    footnote: "Automate when and how often this boundary runs.",
                    items: [
                        ItemParams(name: "Date",   image: "calendar", trailingKind: .toggle),
                        ItemParams(name: "Time",   image: "clock",    trailingKind: .toggle),
                        ItemParams(name: "Repeat", image: "repeat",   trailingKind: .toggle),
                    ]
                ),
                .init(
                    id: "settings",
                    name: "Settings",
                    layout: .group,
                    footnote: "Load closures and services from the library into this boundary.",
                    items: [
                        .init(
                            name: "Controls",
                            image: "switch.2",
                            trailingKind: .load,
                            count: closures.count,
                            items: closures
                        ),
                        .init(
                            name: "Services",
                            image: "arrow.2.squarepath",
                            trailingKind: .load,
                            count: serviceItems.count,
                            items: serviceItems
                        ),
                    ]
                ),
            ]
        )
    }
}

struct PreviewMapper: Mapper {
    static func closures(_ agency: AgencyModel, _ frame: any Panel) -> Closures { .init() }

    static func params(_ studio: AgencyModel, _ frame: any Panel) -> Params {
        .init(
            sections: [
                .init(
                    id: "context",
                    name: "Context",
                    layout: .block,
                    footnote: "The context that will be sent on the next turn.",
                    body: ""
                ),
                .init(
                    id: "output",
                    name: "Last Output",
                    layout: .block,
                    footnote: "The most recent output produced by this boundary.",
                    body: ""
                ),
                .init(
                    id: "usage",
                    name: "Usage",
                    layout: .block,
                    footnote: "Token usage from the last turn.",
                    items: [
                        ItemParams(name: "Input Tokens",  trailingKind: .value, description: "0"),
                        ItemParams(name: "Cached Tokens", trailingKind: .value, description: "0"),
                        ItemParams(name: "Output Tokens", trailingKind: .value, description: "0"),
                    ]
                ),
            ]
        )
    }
}
