import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


//struct SpaceHeaderNew: Surface {
//    var panel: any Panel
//    var model: any Model
//
//    var ref: Reference? { model.session.selection.structure }
//
//    var body: some View {
//        if let ref {
//            HStack(alignment: .center, spacing: 16) {
//                IconButton(systemImage: "plus") { }
//                Text(ref.descriptor.name)
//                Spacer()
//                IconButton(systemImage: "ellipsis") { }
//            }
//            .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
//            .padding(.horizontal, 12)
//            .padding(.bottom, 8)
//        }
//    }
//}
//
//struct SpaceHeader: Surface {
//    var panel: any Panel
//    var model: any Model
//
//    var ref: Reference? { model.session.selection.structure }
//
//    var context: Context? { ref?.context }
//    var harness: Reference? { ref.flatMap { Space.with($0, { $0.harness }) ?? nil } }
//    var working: Bool { context?.state == .working }
//
//    var state: (label: String, tint: Style.Tint) { context?.state.status ?? ("", .neutral) }
//
//    var run: (started: Date, stopped: Date?)? {
//        guard let transcript = model.session.transcript,
//              let entries = Transcript.with(transcript, { $0.entries }),
//              let index = entries.lastIndex(where: { if case .event(.start(_), _) = $0 { true } else { false } })
//                else { return nil }
//        return (entries[index].created, entries[index...].first(where: \.terminal)?.created ?? (working ? nil : entries.last?.created))
//    }
//
//    var body: some View {
//        HStack(alignment: .center) {
//            if let ref {
//                HStack(alignment: .center, spacing: 12) {
//                    Group {
//                        if let harness { Iconography.icon(for: harness, size: 18) }
//                        else { Iconography.icon(for: ref, size: 18) }
//                    }
//                    .frame(maxHeight: 52)
//
//                    Text(ref.descriptor.name)
//                        .frame(alignment: .leading)
//                        .font(.system(size: 14, weight: .medium))
//                        .foregroundStyle(Style.Foreground.primary)
//                        .lineLimit(1)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//
//                    VStack(alignment: .leading) {
//                        if let context {
//                            HStack(spacing: 6) {
//                                Text(context.intent.forms.label)
//                                if let run {
//                                    Text("·")
//                                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
//                                        Text(Duration.seconds((run.stopped ?? timeline.date).timeIntervalSince(run.started).rounded()).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 2)))
//                                            .monospacedDigit()
//                                    }
//                                }
//                            }
//                            .frame(alignment: .leading)
//                            .foregroundStyle(Style.Foreground.secondary)
//                        }
//                    }
//                    .font(Typography.detail)
//                    .lineLimit(1)
//                }
//                .frame(maxHeight: 52)
//            }
//
//            HStack(alignment: .center) {
//                if working { IconButton(systemImage: "pause.fill") { } }
//                else { IconButton(systemImage: "play.fill") { } }
//                IconButton(systemImage: "ellipsis") { }
//            }
//            .frame(maxHeight: 52)
//        }
//        .padding(.horizontal, 10)
//    }
//}
