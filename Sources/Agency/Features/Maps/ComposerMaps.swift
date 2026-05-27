//import SwiftUI
//import AgencyRuntime
//
//
//struct ComposerMap: Mapper {
//    static func closures(_ agency: AgencyModel, _ panel: any Panel) -> Closures {
//        .init(
//            selected: { item in
//                guard let ref = item.ref else { return false }
//                if let entry = item.entryId { return agency.session.selected(ref, entry) }
//                return agency.session.selected(ref)
//            },
//            onSelect: { item in
//                guard let ref = item.ref else { return }
//                agency.select(ref, entry: item.entryId)
//            }
//        )
//    }
//
//    static func params(_ agency: AgencyModel, _ panel: any Panel) -> Params {
//        func render(for event: Event) -> (String, String, Color) {
//            switch event {
//            case .message: return ("Message", "text.bubble", Design.Tint.info)
//            case .reasoning: return ("Reasoning", "brain", Design.Tint.info)
//            case .commandStarted, .commandCompleted: return ("Command", "terminal", Design.Tint.active)
//            case .functionCall: return ("Function", "function", Design.Tint.service)
//            case .functionResult: return ("Result", "function", Design.Tint.service)
//            case .turnFailed, .error: return ("Failed", "exclamationmark.triangle", Design.Tint.failed)
//            case .turnCompleted: return ("Turn", "checkmark", Design.Tint.info)
//            case .unknown(let t, _): return (t, "curlybraces", Design.Tint.active)
//            default: return ("Event", "circle.dotted", Design.Tint.info)
//            }
//        }
//
//        func entries(of transcript: Reference) -> [ItemParams] {
//            (Transcript.with(transcript, { $0.entries }) ?? []).map { entry in
//                switch entry {
//                case .event(let event, let id, _):
//                    let (label, icon, tint) = render(for: event)
//                    return .init(
//                        ref: transcript,
//                        entryId: id,
//                        name: label,
//                        image: icon,
//                        tint: tint,
//                        description: event.content
//                    )
//                case .sheet(let ref, _):
//                    return .init(
//                        ref: ref,
//                        name: "Input",
//                        image: "square.and.pencil",
//                        tint: Design.Tint.info,
//                        description: Sheet.with(ref, { $0.content }) ?? ""
//                    )
//                case .transcript(let ref, _, _):
//                    return .init(
//                        ref: ref,
//                        name: Transcript.with(ref, { $0.name }) ?? "Transcript",
//                        image: "text.bubble",
//                        items: entries(of: ref)
//                    )
//                }
//            }
//        }
//
//        let items = agency.session.transcript.map { entries(of: $0) } ?? []
//
//        return .init(
//            nesting: .recursive,
//            sections: [
//                .init(id: "transcript", name: "Transcript", showsHeader: false,
//                      layout: .list, items: items)
//            ]
//        )
//    }
//}
