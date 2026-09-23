import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SpaceMenu: View {
    @State private var hovered = false
    let model: any Model
    
    var selection: Selection { model.session.selection }
    var path: [Reference] { model.session.navigation.path(for: selection) }

    var body: some View {
        if let ref = path.last {
            Button { model.select(ref) } label: {
                HStack(alignment: .center) {
                    Iconography.icon(for: ref, size: 13.5)
                    Text(ref.descriptor.name).font(.system(size: 13.5, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct SpaceHeader: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
        else { return nil }
        return ref
    }

    var context: Composition? { ref?.context }
    var harness: Reference? { ref.flatMap { Space.with($0, { $0.harness }) ?? nil } }
    var working: Bool { context?.state == .working }

    var state: (label: String, tint: Style.Tint) { context?.state.status ?? ("", .neutral) }

    var run: (started: Date, stopped: Date?)? {
        guard let transcript = model.session.transcript,
              let entries = Transcript.with(transcript, { $0.entries }),
              let index = entries.lastIndex(where: { if case .event(.started(_), _) = $0 { true } else { false } })
        else { return nil }
        return (entries[index].created, entries[index...].first(where: \.terminal)?.created ?? (working ? nil : entries.last?.created))
    }

    var body: some View {
        HStack(alignment: .center) {
            if let ref {
                HStack(alignment: .center, spacing: 12) {
                    Group {
                        if let harness { Iconography.icon(for: harness, size: 18) }
                        else { Iconography.icon(for: ref, size: 18) }
                    }
                    .frame(maxHeight: 52)

                    Text(ref.descriptor.name)
                        .frame(alignment: .leading)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading) {
                        if let context {
                            HStack(spacing: 6) {
                                Text(context.intent.forms.label)
                                if let run {
                                    Text("·")
                                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                        Text(Duration.seconds((run.stopped ?? timeline.date).timeIntervalSince(run.started).rounded()).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow, maximumUnitCount: 2)))
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .frame(alignment: .leading)
                            .foregroundStyle(Style.Foreground.secondary)
                        }
                    }
                    .font(Typography.detail)
                    .lineLimit(1)
                }
                .frame(maxHeight: 52)
            }

            HStack(alignment: .center) {
                if working {
                    Button { } label: {
                        Image(systemName: "pause.fill")
                            .frame(width: 23, height: 23)
                    }
                    .buttonStyle(.accessoryBarAction)
                    .buttonBorderShape(.circle)
                }

                Button { } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 23, height: 23)
                }
                .buttonStyle(.accessoryBarAction)
                .buttonBorderShape(.circle)
            }
            .frame(maxHeight: 52)
        }
        .padding(.horizontal, 10)
    }
}

struct SpaceContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        guard let ref = model.session.selection.structure, Space.with(ref, { $0 }) != nil
        else { return nil }
        return ref
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TranscriptContent(panel: panel, model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Rectangle()
                .fill(Style.Background.canvas)
                .frame(maxHeight: 64, alignment: .bottom)
                .blur(radius: 10, opaque: false)
                .blendMode(.darken)
                .padding(.bottom, -32)
            InputToolbar(model: model, onSend: {})
                .padding([.bottom, .vertical], 10)
        }
        .background(Style.Background.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .top) { SpaceHeader(panel: panel, model: model) }
    }
}
