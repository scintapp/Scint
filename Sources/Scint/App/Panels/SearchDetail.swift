import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SearchDetail: View {
    var ref: Reference
    var model: any Model

    enum Verb: String, CaseIterable {
        case open, execute, insert

        var image: String {
            switch self {
                case .open: "arrow.up.forward.square"
                case .execute: "play"
                case .insert: "text.insert"
            }
        }
    }

    var kind: String { ref.type.map { "\($0)" } ?? "Unknown" }
    var updated: String { ref.descriptor.updated.formatted(date: .abbreviated, time: .shortened) }
    var tags: String { ref.descriptor.tags.sorted().joined(separator: ", ") }
    var verbs: [Verb] { ref.type is Space.Type ? Verb.allCases : [.open, .insert] }

    var body: some View {
        PanelDetail(ref) {
            VStack(spacing: 0) {
                PanelHeader(name: "About")
                PanelRow(name: "Kind", description: kind) { }
                PanelRow(name: "Updated", description: updated) { }
                if !tags.isEmpty { PanelRow(name: "Tags", description: tags) { } }
            }

            VStack(spacing: 0) {
                PanelHeader(name: "Actions")
                ForEach(verbs, id: \.self) { verb in
                    PanelRow(name: verb.rawValue.capitalized, image: verb.image) {
                        switch verb {
                            case .open: model.open(ref)
                            case .execute: model.compose(ref)
                            case .insert: Space.with(model.session.projects, { $0 })?.add(ref)
                        }
                    }
                }
            }
        }
    }
}
