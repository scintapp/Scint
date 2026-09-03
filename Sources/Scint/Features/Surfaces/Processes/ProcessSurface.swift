import SwiftUI


enum ProcessPhase: Equatable {
    case unavailable
    case idle
    case working
    case ready
    case stopped
    case failed

    var label: String {
        switch self {
            case .unavailable: "Not configured"
            case .idle: "Idle"
            case .working: "Working"
            case .ready: "Ready"
            case .stopped: "Stopped"
            case .failed: "Failed"
        }
    }

}

struct ProcessActionItem: Identifiable {
    let id: AnyHashable
    let name: String
    let detail: String?
    let created: Date
}

struct ProcessContent {
    let origin: Reference
    let transcript: Reference?
    let input: Reference?
    let materials: [Reference]
    let intent: Intent?
    let processLabel: String
    let purpose: String
    let phase: ProcessPhase
    let phaseDate: Date?
    let turnCount: Int
    let duration: String
    let latestRequest: String?
    let latestResponse: String?
    let actions: [ProcessActionItem]
    let canSubmit: Bool

    @MainActor init(model: any Model) {
        let origin = model.session.origin
        let transcriptRecord = Self.rootTranscript(model.session.transcript)
        let transcript = transcriptRecord?.ref
        let entries = transcriptRecord?.value.entries ?? []
        let histories = transcriptRecord.map { record in
            [record] + record.value.branches.compactMap { branch in
                Transcript.with(branch) { (ref: branch, value: $0) }
            }
        } ?? []
        let requests = entries.compactMap(Self.request)
        let responses = entries.compactMap(Self.response)
        let actions = histories.flatMap { history in
            history.value.entries.compactMap(Self.action)
        }
        .sorted { $0.created < $1.created }
        let dates = histories.flatMap { history in
            history.value.entries.map(\.created)
        }
        let harness = Self.harness(for: origin).flatMap { reference in
            Harness.with(reference) { (ref: reference, value: $0) }
        }
        let phase = Self.phase(from: entries, configured: harness != nil)
        let input = model.session.input
        let hasInput = input.flatMap { reference in
            Material.with(reference) { material in
                !material.rendered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        } ?? false

        self.origin = origin
        self.transcript = transcript
        self.input = input
        self.materials = model.session.materials.filter {
            $0.descriptor.published && !$0.descriptor.tags.contains("input")
        }
        self.intent = harness?.value.intent
        self.processLabel = harness.map {
            "\($0.value.intent.rawValue.capitalized) process · \($0.ref.descriptor.name)"
        } ?? "No process configured"
        self.purpose = origin.descriptor.description
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.phase = phase
        self.phaseDate = dates.max()
        self.turnCount = requests.count
        self.duration = Self.duration(from: requests.first?.created ?? dates.min(), to: dates.max())
        self.latestRequest = requests.last?.text
        self.latestResponse = responses.last?.text
        self.actions = actions
        self.canSubmit = harness != nil && phase != .working && hasInput
    }

    private static func rootTranscript(_ selected: Reference?) -> (ref: Reference, value: Transcript)? {
        guard let selected, let value = Transcript.with(selected, { $0 }) else { return nil }
        guard value.origin.type is Transcript.Type,
              let root = Transcript.with(value.origin, { $0 })
        else { return (selected, value) }
        return (value.origin, root)
    }

    private static func harness(for origin: Reference) -> Reference? {
        if origin.type is Space.Type {
            return Space.with(origin, { $0.harness }) ?? nil
        }
        if origin.type is Workspace.Type {
            return Workspace.with(origin, { $0.harness }) ?? nil
        }
        return nil
    }

    private static func phase(from entries: [Transcript.Entry], configured: Bool) -> ProcessPhase {
        guard configured else { return .unavailable }

        for entry in entries.reversed() {
            guard case .event(let signal, _) = entry else { continue }
            switch signal {
                case .composed: return .idle
                case .started, .updated: return .working
                case .completed: return .ready
                case .stopped: return .stopped
                case .failed: return .failed
            }
        }

        return .idle
    }

    private static func request(_ entry: Transcript.Entry) -> (text: String, created: Date)? {
        guard case .record(let chunk, let created) = entry,
              chunk.origin.type is Material.Type,
              let text = text(from: chunk.value)
        else { return nil }
        return (text, created)
    }

    private static func response(_ entry: Transcript.Entry) -> (text: String, created: Date)? {
        guard case .record(let chunk, let created) = entry,
              field("type", in: chunk.value) == "message",
              let text = field("text", in: chunk.value)
        else { return nil }
        return (text, created)
    }

    private static func action(_ entry: Transcript.Entry) -> ProcessActionItem? {
        guard case .record(let chunk, let created) = entry,
              field("type", in: chunk.value) == "tool"
        else { return nil }

        let name = field("name", in: chunk.value) ?? chunk.name
        let detail = [field("server", in: chunk.value), field("status", in: chunk.value)]
            .compactMap { $0 }
            .joined(separator: " · ")

        return ProcessActionItem(
            id: chunk.key,
            name: name,
            detail: detail.isEmpty ? nil : detail,
            created: created
        )
    }

    private static func text(from value: Value) -> String? {
        let text: String?
        switch value {
            case .string(let value):
                text = value
            case .collection:
                text = field("text", in: value)
            default:
                text = value.rendered.joined(separator: " ")
        }

        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }

    private static func field(_ name: String, in value: Value) -> String? {
        guard case .collection(let fields) = value, let found = fields[name] else { return nil }
        let rendered = found.rendered.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rendered.isEmpty ? nil : rendered
    }

    private static func duration(from start: Date?, to end: Date?) -> String {
        guard let start, let end else { return "0s" }
        let total = max(Int(end.timeIntervalSince(start).rounded()), 0)
        let minutes = total / 60
        let seconds = total % 60
        guard minutes > 0 else { return "\(seconds)s" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        guard hours > 0 else { return "\(minutes)m \(seconds)s" }
        return "\(hours)h \(remainingMinutes)m"
    }
}

@MainActor protocol ProcessSurfaceRoot {
    var model: any Model { get }
}

extension ProcessSurfaceRoot {
    func selectProcessInput(_ id: AnyHashable, input: Reference) {
        if let ref = id as? Reference {
            model.select(ref)
        } else if let id = id as? UUID {
            model.select(input, entry: id, url: nil)
        }
    }

    func submitProcess(_ content: ProcessContent) {
        guard content.canSubmit, let input = content.input else { return }
        Material.update(input) { $0.clear() }
        model.start(content.origin)
    }
}

struct ProcessFrame<Content: View>: View {
    var tint: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .leading) {
            Style.Background.base

            Rectangle()
                .fill(tint)
                .frame(width: Style.Dimension.border)

            content()
        }
    }
}

struct ProcessHeader: View {
    var origin: Reference
    var transcript: Reference?
    var processLabel: String
    var tint: Color
    var compact: Bool
    var onOpenTranscript: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: compact ? Style.Spacing.md : Style.Spacing.lg) {
            Iconography.icon(
                for: origin,
                size: compact ? Style.Dimension.icon : Style.Dimension.iconLarge
            )

            VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                Text(origin.descriptor.name)
                    .font(compact ? Typography.cardHeading : Typography.title)
                    .foregroundStyle(Style.Foreground.base)
                    .lineLimit(Style.Limit.singleLine)

                Text(processLabel)
                    .font(Typography.caption)
                    .foregroundStyle(tint)
                    .lineLimit(Style.Limit.singleLine)
            }

            Spacer(minLength: Style.Spacing.md)

            if let transcript {
                Button(action: onOpenTranscript) {
                    Iconography.icon(for: transcript, size: Style.Dimension.icon)
                        .frame(width: Style.Dimension.control, height: Style.Dimension.control)
                        .background(Style.Shape.capsule.fill(Style.Background.group))
                        .contentShape(Style.Shape.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Full transcript")
                .help("Full transcript")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProcessMetrics: View {
    var turns: Int
    var actions: Int
    var duration: String
    var compact: Bool

    private var values: [String] {
        [
            "\(turns) \(turns == 1 ? "turn" : "turns")",
            "\(actions) \(actions == 1 ? "action" : "actions")",
            duration,
        ]
    }

    var body: some View {
        if compact {
            HStack(spacing: Style.Spacing.md) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    if index > values.startIndex {
                        Text("·")
                            .foregroundStyle(Style.Foreground.faint)
                    }
                    Text(value)
                }
            }
            .font(Typography.caption)
            .foregroundStyle(Style.Foreground.muted)
            .lineLimit(Style.Limit.singleLine)
        } else {
            HStack(spacing: Style.Spacing.md) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Text(value)
                        .font(Typography.cardTitle)
                        .foregroundStyle(Style.Foreground.subtle)
                        .padding(.horizontal, Style.Spacing.lg)
                        .padding(.vertical, Style.Spacing.md)
                        .background(Style.Shape.capsule.fill(Style.Background.group))
                }
            }
        }
    }
}

struct ProcessSection<Content: View>: View {
    var title: String
    var tint: Color
    var compact: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Style.Spacing.lg : Style.Spacing.xl) {
            Text(title)
                .font(Typography.cardTitle)
                .foregroundStyle(tint)

            content()
        }
        .padding(compact ? .zero : Style.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if !compact {
                Style.Shape.medium.fill(Style.Background.panel)
            }
        }
        .overlay {
            if !compact {
                Style.Shape.medium.strokeBorder(
                    Style.Border.base,
                    lineWidth: Style.Dimension.border,
                    antialiased: true
                )
            }
        }
    }
}

struct ProcessStatus: View {
    var phase: ProcessPhase
    var date: Date?
    var processTint: Color
    var compact: Bool

    private var symbol: String {
        switch phase {
            case .unavailable: Iconography.Custom.inactive.rawValue
            case .idle: Iconography.Custom.active.rawValue
            case .working: Iconography.Custom.running.rawValue
            case .ready: Iconography.Custom.completed.rawValue
            case .stopped: Iconography.Custom.blocked.rawValue
            case .failed: Iconography.Custom.failed.rawValue
        }
    }

    private var tint: Color {
        switch phase {
            case .unavailable: Style.Foreground.faint
            case .idle, .stopped: Style.Foreground.muted
            case .working: processTint
            case .ready: Style.Tint.command
            case .failed: Style.Tint.alert
        }
    }

    var body: some View {
        HStack(spacing: Style.Spacing.md) {
            Iconography.Icon(
                symbol: symbol,
                tint: tint,
                sizing: Style.Dimension.icon,
                selected: true
            )

            Text(phase.label)
                .foregroundStyle(tint)

            if let date {
                Text("·")
                    .foregroundStyle(Style.Foreground.faint)
                Text(date, style: .relative)
                    .foregroundStyle(Style.Foreground.muted)
            }

            Spacer(minLength: .zero)
        }
        .font(compact ? Typography.caption : Typography.cardRow)
    }
}

struct ProcessMaterials: View {
    var materials: [Reference]
    var selected: Reference?
    var compact: Bool
    var onOpen: (Reference) -> Void

    var body: some View {
        VStack(spacing: compact ? Style.Spacing.sm : Style.Spacing.md) {
            ForEach(materials) { material in
                let descriptor = material.descriptor
                let isSelected = selected == material

                Button { onOpen(material) } label: {
                    HStack(alignment: .top, spacing: Style.Spacing.lg) {
                        Iconography.icon(for: material, size: Style.Dimension.icon)
                            .padding(.top, Style.Spacing.xs)

                        VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                            Text(descriptor.name)
                                .font(Typography.cardRow)
                                .foregroundStyle(Style.Foreground.base)
                                .lineLimit(compact ? Style.Limit.doubleLine : Style.Limit.singleLine)

                            if !descriptor.description.isEmpty {
                                Text(descriptor.description)
                                    .font(Typography.caption)
                                    .foregroundStyle(Style.Foreground.muted)
                                    .lineLimit(compact ? Style.Limit.singleLine : Style.Limit.doubleLine)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Iconography.Icon(
                            symbol: "arrow.up.right",
                            tint: Style.Foreground.faint,
                            sizing: Style.Spacing.lg,
                            selected: true
                        )
                    }
                    .padding(.horizontal, compact ? Style.Spacing.md : Style.Spacing.lg)
                    .padding(.vertical, Style.Spacing.md)
                    .background {
                        Style.Shape.small.fill(
                            isSelected ? Style.Background.raised : Style.Background.group
                        )
                    }
                    .overlay {
                        Style.Shape.small.strokeBorder(
                            isSelected
                                ? Style.Tint.material.opacity(Style.Opacity.muted)
                                : Style.Border.raised,
                            lineWidth: Style.Dimension.border,
                            antialiased: true
                        )
                    }
                    .contentShape(Style.Shape.small)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProcessLatestTurn: View {
    var request: String?
    var response: String?
    var tint: Color
    var compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Style.Spacing.lg : Style.Spacing.xl) {
            if let request {
                message("You", text: request, tint: tint)
            }

            if let response {
                message("Agent", text: response, tint: Style.Tint.command)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func message(_ label: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Style.Spacing.sm) {
            Text(label)
                .font(Typography.cardTitle)
                .foregroundStyle(tint)

            Text(text)
                .font(compact ? Typography.cardRow : Typography.prose)
                .foregroundStyle(Style.Foreground.base)
                .lineSpacing(Style.Spacing.sm)
                .lineLimit(compact ? Style.Limit.doubleLine : nil)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

struct ProcessActions: View {
    var actions: [ProcessActionItem]
    var compact: Bool

    private var visibleActions: [ProcessActionItem] {
        compact ? (actions.last.map { [$0] } ?? []) : actions
    }

    var body: some View {
        VStack(spacing: compact ? Style.Spacing.sm : Style.Spacing.md) {
            ForEach(visibleActions) { action in
                HStack(alignment: .firstTextBaseline, spacing: Style.Spacing.lg) {
                    Iconography.Icon(
                        symbol: "chevron.right",
                        tint: Style.Tint.command,
                        sizing: Style.Spacing.lg,
                        selected: true
                    )

                    VStack(alignment: .leading, spacing: Style.Spacing.xs) {
                        Text(action.name)
                            .font(Typography.cardDetail(.monospaced))
                            .foregroundStyle(Style.Foreground.base)
                            .lineLimit(compact ? Style.Limit.singleLine : Style.Limit.doubleLine)

                        if let detail = action.detail {
                            Text(detail)
                                .font(Typography.caption)
                                .foregroundStyle(Style.Foreground.muted)
                                .lineLimit(Style.Limit.singleLine)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(action.created, style: .relative)
                        .font(Typography.label)
                        .foregroundStyle(Style.Foreground.faint)
                        .lineLimit(Style.Limit.singleLine)
                }
                .padding(.horizontal, compact ? Style.Spacing.md : Style.Spacing.lg)
                .padding(.vertical, Style.Spacing.md)
                .background(Style.Shape.small.fill(Style.Background.group))
            }
        }
    }
}

struct ProcessComposer: View {
    var input: Reference
    var tint: Color
    var compact: Bool
    var active: Bool
    var canSubmit: Bool
    var onFocus: (AnyHashable) -> Void
    var onSubmit: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            EditorComponent(
                input,
                autofocus: false,
                active: active,
                minHeight: compact ? Style.Spacing.rowDetailHeight : Style.Spacing.cardHeight,
                maxHeight: Style.Dimension.assignmentDescriptionHeight,
                onFocus: onFocus
            )
            .id(input)
            .padding(.leading, Style.Spacing.xl)
            .padding(.trailing, Style.Dimension.control + Style.Spacing.xxl)
            .padding(.vertical, Style.Spacing.md)

            Button(action: onSubmit) {
                Iconography.Icon(
                    symbol: "paperplane.fill",
                    tint: tint,
                    sizing: Style.Dimension.icon,
                    selected: canSubmit
                )
                .frame(width: Style.Dimension.control, height: Style.Dimension.control)
                .background {
                    Style.Shape.capsule.fill(
                        canSubmit ? tint : Style.Background.control
                    )
                }
                .contentShape(Style.Shape.capsule)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSubmit)
            .opacity(canSubmit ? Style.Opacity.full : Style.Opacity.faint)
            .padding(.trailing, Style.Spacing.lg)
            .padding(.bottom, Style.Spacing.lg)
            .accessibilityLabel("Send")
            .help("Send")
        }
        .background(Style.Shape.medium.fill(Style.Background.group))
        .overlay {
            Style.Shape.medium.strokeBorder(
                Style.Border.base,
                lineWidth: Style.Dimension.border,
                antialiased: true
            )
        }
        .clipShape(Style.Shape.medium)
    }
}

struct ProcessLayout: View {
    var content: ProcessContent
    var selectedMaterial: Reference?
    var activeInput: Reference?
    var compact: Bool
    var onOpenTranscript: () -> Void
    var onOpenMaterial: (Reference) -> Void
    var onFocusInput: (AnyHashable) -> Void
    var onSubmit: () -> Void

    private var horizontalPadding: CGFloat {
        compact ? Style.Spacing.xl : Style.Spacing.xxxl
    }

    private var sectionSpacing: CGFloat {
        compact ? Style.Spacing.xxl : Style.Spacing.xxxl
    }

    private var tint: Color {
        guard let intent = content.intent else { return Style.Tint.space }
        return Iconography.icon(for: intent).tint
    }

    var body: some View {
        ProcessFrame(tint: tint) {
            VStack(spacing: .zero) {
                ProcessHeader(
                    origin: content.origin,
                    transcript: content.transcript,
                    processLabel: content.processLabel,
                    tint: tint,
                    compact: compact,
                    onOpenTranscript: onOpenTranscript
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.top, Style.Spacing.xxl)
                .padding(.bottom, Style.Spacing.xl)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                        ProcessMetrics(
                            turns: content.turnCount,
                            actions: content.actions.count,
                            duration: content.duration,
                            compact: compact
                        )

                        if !content.purpose.isEmpty {
                            ProcessSection(title: "Purpose", tint: tint, compact: compact) {
                                Text(content.purpose)
                                    .font(compact ? Typography.cardRow : Typography.prose)
                                    .foregroundStyle(Style.Foreground.base)
                                    .lineSpacing(Style.Spacing.sm)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }

                        ProcessSection(title: "Current state", tint: tint, compact: compact) {
                            ProcessStatus(
                                phase: content.phase,
                                date: content.phaseDate,
                                processTint: tint,
                                compact: compact
                            )
                        }

                        if !content.materials.isEmpty {
                            ProcessSection(title: "Materials", tint: tint, compact: compact) {
                                ProcessMaterials(
                                    materials: content.materials,
                                    selected: selectedMaterial,
                                    compact: compact,
                                    onOpen: onOpenMaterial
                                )
                            }
                        }

                        if content.latestRequest != nil || content.latestResponse != nil {
                            ProcessSection(title: "Latest turn", tint: tint, compact: compact) {
                                ProcessLatestTurn(
                                    request: content.latestRequest,
                                    response: content.latestResponse,
                                    tint: tint,
                                    compact: compact
                                )
                            }
                        }

                        if !content.actions.isEmpty {
                            ProcessSection(title: "Recent actions", tint: tint, compact: compact) {
                                ProcessActions(actions: content.actions, compact: compact)
                            }
                        }
                    }
                    .frame(
                        maxWidth: compact ? .infinity : Style.Spacing.contentMaxWidth,
                        alignment: .leading
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, Style.Spacing.xxl)
                }
                .scrollEdgeEffectStyle(.hard, for: .vertical)

                if let input = content.input {
                    ProcessComposer(
                        input: input,
                        tint: tint,
                        compact: compact,
                        active: activeInput == input,
                        canSubmit: content.canSubmit,
                        onFocus: onFocusInput,
                        onSubmit: onSubmit
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, Style.Spacing.xl)
                    .background(Style.Background.base)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ProcessSurface: Surface, ProcessSurfaceRoot {
    var panel: any Panel
    var model: any Model

    var body: some View {
        let content = ProcessContent(model: model)

        ProcessLayout(
            content: content,
            selectedMaterial: model.session.opened.material,
            activeInput: model.session.selected.content,
            compact: false,
            onOpenTranscript: {
                if let transcript = content.transcript { model.open(transcript) }
            },
            onOpenMaterial: { model.open($0) },
            onFocusInput: {
                guard let input = content.input else { return }
                selectProcessInput($0, input: input)
            },
            onSubmit: { submitProcess(content) }
        )
    }
}
