import AgencyRuntime
import Foundation
import SwiftUI


struct ConsoleMonitorView: View {
    let model: ConsoleMonitorModel
    let expandedRows: Set<AnyHashable>
    let actions: Actions

    struct Actions {
        var toggleRow: (AnyHashable) -> Void = { _ in }
        var openTranscript: (Reference, Reference) -> Void = { _, _ in }
    }

    var body: some View {
        if model.visibleCompositions.isEmpty {
            MonitorEmptyState(title: "No matching processes", systemImage: "waveform.path.ecg")
        } else {
            TableLayout(
                section: section,
                columns: columns,
                closures: tableClosures
            )
        }
    }

    private var columns: [ColumnParams] {
        [
            .init(id: "state-mark", title: "", width: 34, value: .text("")),
            .init(id: "process", title: "Process", width: 360, value: .primary),
            .init(id: "intents", title: "Intents", width: 250, alignment: .trailing, value: .tags),
            .init(id: "activity", title: "", width: 72, alignment: .trailing, value: .text("")),
            .init(id: "elapsed", title: "Time", width: 56, alignment: .trailing, value: .description),
            .init(id: "state", title: "State", width: 78, alignment: .trailing, value: .badge),
            .init(id: "disclosure", title: "", width: 18, alignment: .trailing, value: .text(""))
        ]
    }

    private var section: ListParams {
        .init(
            id: "console-monitor",
            showsHeader: false,
            layout: .table,
            items: model.visibleCompositions.map(item)
        )
    }

    private var tableClosures: Closures {
        .init(
            onSelect: { item in actions.toggleRow(item.id) },
            onOpen: { item in
                guard let composition = composition(for: item) else { return }
                actions.openTranscript(composition.transcript, composition.origin)
            },
            tableExpanded: { expandedRows.contains($0.id) },
            tableDetail: detail,
            tableCell: cell
        )
    }

    private func item(_ composition: Composition) -> ItemParams {
        .init(
            ref: composition.origin,
            origin: composition.origin,
            name: composition.origin.name,
            image: Design.Component.icon(for: composition.origin),
            description: elapsedText(for: composition),
            badges: [.init(icon: "circle.fill", label: composition.state.consoleName, count: 0, tint: composition.state.consoleTint)],
            items: [.init(name: subtitle(for: composition), description: nil)]
        )
    }

    private func composition(for item: ItemParams) -> Composition? {
        guard let ref = item.ref else { return nil }
        return model.visibleCompositions.first { $0.origin == ref }
    }

    private func subtitle(for composition: Composition) -> String {
        if let latest = Transcript.with(composition.transcript, { $0.content.last ?? "" }),
           !latest.isEmpty {
            return latest
        }

        return composition.intention.isEmpty ? "no active intents" : composition.state.consoleName.lowercased()
    }

    private func elapsedText(for composition: Composition) -> String? {
        Transcript.with(composition.transcript) { transcript in
            guard let started = transcript.started else { return nil }

            let stopped = transcript.stopped ?? Date()
            let seconds = max(0, Int(stopped.timeIntervalSince(started)))
            return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
        } ?? nil
    }

    private func detail(for item: ItemParams) -> AnyView? {
        guard let composition = composition(for: item) else { return nil }
        return AnyView(
            ConsoleMonitorDetails(composition: composition, actions: actions)
                .padding(.leading, 50)
                .padding(.trailing, 24)
                .padding(.bottom, 16)
        )
    }

    private func cell(_ column: ColumnParams, _ item: ItemParams) -> AnyView? {
        guard let composition = composition(for: item) else { return nil }

        switch column.id {
        case AnyHashable("state-mark"):
            return AnyView(MonitorStateMark(state: composition.state).frame(width: 28, height: 28))
        case AnyHashable("process"):
            return AnyView(ConsoleProcessCell(composition: composition, subtitle: subtitle(for: composition)))
        case AnyHashable("intents"):
            return AnyView(ConsoleIntentTokens(intentions: composition.intention))
        case AnyHashable("activity"):
            return AnyView(MonitorSparkline(active: composition.state == .running, tint: composition.state.consoleTint, seed: composition.origin.id.hashValue))
        case AnyHashable("elapsed"):
            return AnyView(ConsoleElapsedCell(text: elapsedText(for: composition) ?? "none"))
        case AnyHashable("state"):
            return AnyView(MonitorStatusPill(title: composition.state.consoleName, tint: composition.state.consoleTint))
        case AnyHashable("disclosure"):
            return AnyView(ConsoleDisclosureCell(expanded: expandedRows.contains(item.id)))
        default:
            return nil
        }
    }
}

struct ConsoleMonitorFilterStrip: View {
    let model: ConsoleMonitorModel
    let selection: ConsoleMonitorFilter
    let onSelect: (ConsoleMonitorFilter) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ConsoleMonitorFilter.allCases, id: \.self) { filter in
                MonitorCountPill(
                    title: filter.title,
                    count: model.count(for: filter),
                    tint: filter.consoleTint,
                    selected: filter == selection
                ) {
                    onSelect(filter)
                }
            }
        }
    }
}

private struct ConsoleProcessCell: View {
    let composition: Composition
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(composition.origin.name)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.72))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ConsoleElapsedCell: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary.opacity(0.74))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ConsoleDisclosureCell: View {
    let expanded: Bool

    var body: some View {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 18)
    }
}

private struct ConsoleMonitorDetails: View {
    let composition: Composition
    let actions: ConsoleMonitorView.Actions

    private var contentSummary: String {
        var artifacts = 0
        var controls = 0
        var sheets = 0

        for item in composition.content {
            switch item {
            case .artifact: artifacts += 1
            case .control: controls += 1
            case .sheet: sheets += 1
            }
        }

        return "content - \(artifacts) artifacts - \(controls) controls - \(sheets) sheets"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                MonitorActionButton(title: "Pause", systemImage: "pause", enabled: false) {}
                MonitorActionButton(title: "Stop", systemImage: "stop", enabled: false) {}
                MonitorActionButton(title: "Transcript", systemImage: "doc.text") {
                    actions.openTranscript(composition.transcript, composition.origin)
                }
            }

            Text("state = composition.state -> \(composition.state.consoleName.lowercased())")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)

            if composition.intention.isEmpty {
                MonitorDetailLine(systemImage: "moon", tint: Composition.State.idle.consoleTint, text: "no active intents")
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    ForEach(Array(composition.intention.enumerated()), id: \.offset) { _, intention in
                        ConsoleIntentionDetail(intention: intention)
                    }
                }
            }

            Divider().opacity(0.35)
            Text(contentSummary)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ConsoleIntentTokens: View {
    let intentions: [Composition.Intention]

    private var primaryReference: Reference? {
        intentions.first.map(consoleIntentReference)
    }

    var body: some View {
        HStack(spacing: 6) {
            let visibleIntentions = Array(intentions.prefix(3))
            ForEach(Array(visibleIntentions.enumerated()), id: \.offset) { _, intention in
                MonitorToken(
                    title: consoleIntentName(intention),
                    tint: consoleIntentTint(intention),
                    outlined: primaryReference.map { $0 == consoleIntentReference(intention) } ?? false
                )
            }
        }
    }
}

private struct ConsoleIntentionDetail: View {
    let intention: Composition.Intention

    private var entries: [Transcript.Entry] {
        Transcript.with(consoleIntentReference(intention), { Array($0.entries.suffix(3)) }) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(consoleIntentName(intention))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.primary)
                Text("- \(Transcript.with(consoleIntentReference(intention), { $0.name }) ?? "Transcript")")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(entries, id: \.id) { entry in
                MonitorDetailLine(
                    systemImage: consoleEntryIcon(entry),
                    tint: consoleEntryTint(entry),
                    text: consoleEntryText(entry)
                )
            }
        }
    }
}

private extension ConsoleMonitorFilter {
    var consoleTint: Color {
        state?.consoleTint ?? .primary.opacity(0.85)
    }
}

private func consoleIntentReference(_ intention: Composition.Intention) -> Reference {
    switch intention {
    case .dispatch(let ref), .observe(let ref), .process(let ref), .traverse(let ref):
        ref
    }
}

private func consoleIntentName(_ intention: Composition.Intention) -> String {
    switch intention {
    case .dispatch: "dispatch"
    case .observe: "observe"
    case .process: "process"
    case .traverse: "traverse"
    }
}

private func consoleIntentTint(_ intention: Composition.Intention) -> Color {
    switch intention {
    case .dispatch: Design.Tint.failed
    case .observe: Design.Tint.active
    case .process: Design.Tint.running
    case .traverse: Design.Tint.ready
    }
}

private func consoleEntryText(_ entry: Transcript.Entry) -> String {
    switch entry {
    case .event(let event, _, _):
        event.provider.map { $0.text.isEmpty ? $0.name : $0.text } ?? String(describing: event)
    case .sheet(let ref, _):
        Sheet.with(ref, { $0.content }) ?? ref.name
    case .transcript(let ref, _, _):
        Transcript.with(ref, { $0.name }) ?? ref.name
    }
}

private func consoleEntryIcon(_ entry: Transcript.Entry) -> String {
    switch entry {
    case .event(let event, _, _):
        event.provider == nil ? "chevron.forward" : "waveform.path.ecg"
    case .sheet:
        "doc.text"
    case .transcript:
        "chevron.forward"
    }
}

private func consoleEntryTint(_ entry: Transcript.Entry) -> Color {
    switch entry {
    case .event(let event, _, _):
        event.provider == nil ? .secondary : Design.Tint.info
    case .sheet:
        Design.Tint.info
    case .transcript:
        .secondary
    }
}
