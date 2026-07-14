import AgencyRuntime
import SwiftUI


enum RunState: String, CaseIterable, Identifiable {
    case idle = "Idle"
    case active = "Active"
    case running = "Running"
    case blocked = "Blocked"
    case failed = "Failed"

    var id: String { rawValue }

    init(_ state: AgencyRuntime.Process.State) {
        switch state {
        case .idle: self = .idle
        case .active: self = .active
        case .running: self = .running
        case .blocked: self = .blocked
        case .failed: self = .failed
        }
    }

    var badgeSymbol: String {
        switch self {
        case .idle: return Iconography.Custom.inactive.rawValue
        case .active: return Iconography.Custom.active.rawValue
        case .running: return Iconography.Custom.running.rawValue
        case .blocked: return Iconography.Custom.blocked.rawValue
        case .failed: return Iconography.Custom.failed.rawValue
        }
    }

    var tint: Color {
        switch self {
        case .idle: return Design.Tint.inactive
        case .active: return Design.Tint.active
        case .running: return Design.Tint.running
        case .blocked: return Design.Tint.blocked
        case .failed: return Design.Tint.failed
        }
    }

    var subdued: Bool { self == .idle }
}

enum RunIntent: String {
    case compose = "Compose"
    case dispatch = "Dispatch"
    case execute = "Execute"
    case observe = "Observe"
    case traverse = "Traverse"
    case unknown = "No Harness"

    init(_ modality: Harness.Modality?) {
        switch modality {
        case .compose: self = .compose
        case .dispatch: self = .dispatch
        case .execute: self = .execute
        case .observe: self = .observe
        case .traverse: self = .traverse
        case nil: self = .unknown
        }
    }

    @MainActor var icon: Iconography.Icon {
        switch self {
        case .compose: return Iconography.icon(for: .compose, size: 13)
        case .dispatch: return Iconography.icon(for: .dispatch, size: 13)
        case .execute: return Iconography.icon(for: .execute, size: 13)
        case .observe: return Iconography.icon(for: .observe, size: 13)
        case .traverse: return Iconography.icon(for: .traverse, size: 13)
        case .unknown: return Iconography.Icon(symbol: "questionmark.circle", tint: Design.Tint.inactive, sizing: 13)
        }
    }

    @MainActor var tint: Color {
        switch self {
        case .unknown: return Design.Tint.inactive
        default: return icon.tint
        }
    }
}

struct ProcessSnapshot: Identifiable {
    let process: AgencyRuntime.Process

    var id: Reference { process.origin }
    var title: String { process.origin.descriptor.name }
    var state: RunState { .init(process.state) }
    var intent: RunIntent { .init(modality) }
    var summary: String { Self.summary(for: process) }
    var count: Int { Self.eventCount(in: process.transcript) }
    var countLabel: String { count == 1 ? "1e" : "\(count)e" }
    var actions: [String] { ["Open"] }

    private var modality: Harness.Modality? {
        process.harness.flatMap { Harness.with($0, { $0.modality }) }
    }

    static func all() -> [Self] {
        Runtime.shared.context()
            .filter { !$0.intents.isEmpty }
            .map(Self.init)
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private static func summary(for process: AgencyRuntime.Process) -> String {
        let events = events(in: process.transcript)
        for event in events.reversed() {
            if let content = event.response?.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
                return compact(content)
            }
            return label(for: event)
        }
        return "No events"
    }

    private static func eventCount(in transcript: Reference) -> Int {
        events(in: transcript).count
    }

    private static func events(in transcript: Reference) -> [RuntimeEvent] {
        guard let entries = Transcript.with(transcript, { $0.entries }) else { return [] }
        return entries.flatMap { entry -> [RuntimeEvent] in
            switch entry {
            case .event(let event, _, _): return [event]
            case .input(_, _): return []
            case .transcript(let ref, _, _): return events(in: ref)
            }
        }
    }

    private static func compact(_ value: String) -> String {
        value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func label(for event: RuntimeEvent) -> String {
        switch event {
        case .request: return "Requested"
        case .composing: return "Composing"
        case .dispatching: return "Dispatching"
        case .observing: return "Observing"
        case .processing: return "Processing"
        case .traversing: return "Traversing"
        case .updated: return "Updated"
        case .blocked: return "Blocked"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .properties: return "Received event"
        }
    }
}

struct ProcessCard: View {
    let process: ProcessSnapshot
    let selected: Bool
    let onSelect: () -> Void
    let onAction: (String) -> Void

    var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }
    var hasTranscriptAction: Bool { process.actions.contains("Open") }
    var contextActions: [String] { process.actions.filter { $0 != "Open" } }
    var intentIcon: Iconography.Icon { process.intent.icon }

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack {
                HStack(alignment: .top) {
                    Text(process.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.Foreground.primary)
                        .lineLimit(1)
                }

                Spacer()

                HStack {
                    Text(process.countLabel)
                        .font(.system(size: 10.5, weight: .light, design: .monospaced))
                        .foregroundStyle(process.state.tint.opacity(process.state.subdued ? 0.7 : 0.96))
                        .lineLimit(1)
                    intentIcon.frame(width: 18, height: 18)
                }
                .frame(width: 34, alignment: .topTrailing)
                .help(process.intent.rawValue)
            }
            .frame(height: 28)

            VStack(alignment: .leading) {
                Text(process.summary)
                    .lineLimit(3)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Design.Foreground.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(alignment: .top)
            }
            .frame(height: 48)

            HStack(spacing: 4) {
                if hasTranscriptAction { ActionButton(title: "Open", onAction: onAction) }
                Spacer()
                ForEach(contextActions, id: \.self) { action in ActionButton(title: action, onAction: onAction) }
            }
            .frame(height: 26)
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(alignment: .topLeading)
        .contentShape(shape)
        .onTapGesture { onSelect() }
        .background { shape.fill(Design.Background.base) }
        .overlay { shape.fill(process.intent.tint.opacity(0.015)) }
        .background { shape.glassEffect(.clear, in: shape) }
        .overlay { shape.strokeBorder(Design.Foreground.primary.opacity(selected ? 0.12 : 0.06), lineWidth: 1.0) }
        .overlay { shape.strokeBorder(process.intent.tint.opacity(selected ? 0.24 : 0.12), lineWidth: 0.5) }
    }
}

struct Processes: View {
    @Environment(AgencyModel.self) var agency
    @State private var selected: Reference?
    @State private var refresh = 0

    private var processes: [ProcessSnapshot] {
        _ = refresh
        return ProcessSnapshot.all()
    }

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 360), spacing: 24, alignment: .topLeading)
    ]

    var body: some View {
        ScrollView {
            if processes.isEmpty {
                Text("No Processes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Design.Foreground.quaternary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach(processes) { process in
                        ProcessCard(
                            process: process,
                            selected: selected == process.id,
                            onSelect: {
                                selected = process.id
                                agency.select(process.process.origin)
//                                agency.studio.canvas.model = .composer
                            },
                            onAction: { action in
                                guard action == "Open" else { return }
                                selected = process.id
//                                agency.select(process.process.origin)
//                                agency.studio.canvas.model = .composer
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { Design.Background.console }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 750_000_000)
                refresh &+= 1
            }
        }
    }
}
