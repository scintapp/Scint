import AgencyRuntime
import SwiftUI


enum TranscriptItem {
    case message(String)
    case code(String)
    case reasoning(String)
    case action(verb: String, name: String, output: String)
    case status([String])
    case domain(label: String, events: [String])
    case state(AgencyRuntime.Process.State, String)

    var isMessage: Bool { if case .message = self { return true }; return false }
    var isStatus: Bool  { if case .status  = self { return true }; return false }
    var isReasoning: Bool { if case .reasoning = self { return true }; return false }
}

private extension RuntimeEvent {
    var transcriptLabel: String {
        switch self {
            case .request: return "requested"
            case .composing: return "composed"
            case .dispatching: return "dispatching"
            case .observing: return "observing"
            case .processing: return "processing"
            case .traversing: return "traversing"
            case .updated: return "updated"
            case .completed: return "completed"
            case .blocked: return "blocked"
            case .failed: return "failed"
            case .properties(let properties): return ModelResponse(properties).content
        }
    }
}

private extension AgencyRuntime.Process.State {
    var transcriptColor: Color {
        switch self {
            case .failed: return Design.Tint.failed
            case .blocked: return Design.Tint.blocked
            default: return Design.Foreground.tertiary
        }
    }
    
    var transcriptIcon: String {
        switch self {
            case .failed: return "exclamationmark.triangle"
            case .blocked: return "hand.raised"
            default: return "circle"
        }
    }
}

private enum TranscriptBlock: Identifiable {
    case message(String, UUID)
    case reasoning(String, UUID)
    case action(verb: String, name: String, output: String, UUID)
    case status([String], UUID)
    case domain(label: String, events: [String], UUID)
    case state(AgencyRuntime.Process.State, String, UUID)
    case input(Reference, UUID)
    case nested(Reference, UUID)
    
    var id: UUID {
        switch self {
            case .message(_, let id), .reasoning(_, let id),
                    .action(_, _, _, let id), .status(_, let id),
                    .domain(_, _, let id), .state(_, _, let id),
                    .input(_, let id), .nested(_, let id):
                return id
        }
    }
    
    static func blocks(from entries: [Transcript.Entry]) -> [TranscriptBlock] {
        var blocks: [TranscriptBlock] = []
        
        var deltas: [String] = []; var deltaID: UUID?
        var status: [String] = []; var statusID: UUID?
        var domain: [String] = []; var domainID: UUID?
        
        func flushMessage() {
            guard !deltas.isEmpty else { return }
            let text = deltas.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { blocks.append(.message(text, deltaID ?? UUID())) }
            deltas.removeAll(); deltaID = nil
        }
        func flushStatus() {
            guard !status.isEmpty else { return }
            blocks.append(.status(status, statusID ?? UUID()))
            status.removeAll(); statusID = nil
        }
        func flushDomain() {
            guard !domain.isEmpty else { return }
            blocks.append(.domain(label: "composition", events: domain, domainID ?? UUID()))
            domain.removeAll(); domainID = nil
        }
        func flushAll() { flushMessage(); flushStatus(); flushDomain() }
        
        for entry in entries {
            switch entry {
                case .event(let event, let id, _):
                    if let provider = event.response {
                        switch provider.kind {
                            case .response:
                                flushStatus(); flushDomain()
                                if deltaID == nil { deltaID = id }
                                deltas.append(provider.content)
                                
                            case .message:
                                flushAll()
                                let text = provider.content.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty { blocks.append(.message(text, id)) }
                                
                            case .reasoning:
                                flushAll()
                                blocks.append(.reasoning(provider.content, id))
                                
                            case .command:
                                flushAll()
                                let output = trimmingLeadingLine(provider.content, equalTo: provider.name)
                                blocks.append(.action(verb: "ran", name: provider.name, output: output, id))
                                
                            case .function:
                                flushAll()
                                blocks.append(.action(verb: "called",
                                                      name: provider.name.isEmpty ? "function" : provider.name,
                                                      output: provider.content, id))
                                
                            case .other:
                                flushMessage(); flushDomain()
                                if statusID == nil { statusID = id }
                                status.append(provider.content.isEmpty ? "event" : provider.content)
                        }
                    } else {
                        switch event {
                            case .request, .composing, .completed:
                                flushMessage(); flushStatus()
                                if domainID == nil { domainID = id }
                                domain.append(event.label)
                                
                            case .dispatching, .observing, .processing, .traversing, .updated:
                                flushMessage(); flushDomain()
                                if statusID == nil { statusID = id }
                                status.append(event.label)
                                
                            case .blocked:
                                flushAll()
                                blocks.append(.state(.blocked, "blocked · awaiting input", id))
                                
                            case .failed:
                                flushAll()
                                blocks.append(.state(.failed, "failed", id))
                                
                            case .properties:
                                break
                        }
                    }
                    
                case .sheet(let ref, _):
                    flushAll()
                    blocks.append(.input(ref, entry.id))
                    
                case .transcript(let ref, _, _):
                    flushAll()
                    blocks.append(.nested(ref, entry.id))
            }
        }
        
        flushAll()
        return blocks
    }
    
    private static func trimmingLeadingLine(_ text: String, equalTo name: String) -> String {
        guard !name.isEmpty, text.hasPrefix(name) else { return text }
        return String(text.dropFirst(name.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct TranscriptEntriesView: View {
    let entries: [Transcript.Entry]
    var showStatus: Bool = true
    var showReasoning: Bool = true
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.blockSpacing) {
            ForEach(TranscriptBlock.blocks(from: entries)) { block in
                view(for: block)
            }
        }
    }
    
    @ViewBuilder
    private func view(for block: TranscriptBlock) -> some View {
        switch block {
            case .message(let text, _):
                MessageView(text: text)
                
            case .reasoning(let text, _):
                if showReasoning { ReasoningView(text: text) }
                
            case .action(let verb, let name, let output, _):
                ActionRow(verb: verb, name: name, output: output)
                
            case .status(let lines, _):
                if showStatus { StatusRow(lines: lines) }
                
            case .domain(let label, let events, _):
                DomainRollup(label: label, events: events)
                
            case .state(let state, let text, _):
                StateRow(state: state, text: text)
                
            case .input(let ref, _):
                TranscriptInputView(ref: ref)
                
            case .nested(let ref, _):
                TranscriptNestedView(ref: ref, showStatus: showStatus, showReasoning: showReasoning)
        }
    }
}

struct TranscriptInputView: View {
    let ref: Reference
    private var content: String { Sheet.with(ref, { $0.rendered }) ?? "" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil").font(.system(size: 10, weight: .light))
                Text("Input").font(Typography.label)
            }
            .foregroundStyle(Design.Foreground.tertiary)
            
            Text(content)
                .font(Typography.message)
                .foregroundStyle(Design.Foreground.caption)
                .lineSpacing(Spacing.lineSpacingMessage)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.blockPaddingV)
        .padding(.horizontal, Spacing.blockPaddingH)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.blockRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.blockRadius, style: .continuous)
                .stroke(Design.Border.block, lineWidth: 1)
        }
    }
}

struct TranscriptNestedView: View {
    let ref: Reference
    var showStatus: Bool = true
    var showReasoning: Bool = true
    
    private var name: String { Transcript.with(ref, { $0.name }) ?? "Transcript" }
    private var entries: [Transcript.Entry] { Transcript.with(ref, { $0.entries }) ?? [] }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right").font(.system(size: 10, weight: .light))
                Text(name).font(Typography.label)
            }
            .foregroundStyle(Design.Foreground.tertiary)
            
            TranscriptEntriesView(entries: entries, showStatus: showStatus, showReasoning: showReasoning)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Design.Border.block).frame(width: 1)
                }
        }
    }
}

struct TranscriptStatusIndicator: View {
    @State private var phase = false
    
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Design.Foreground.tertiary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase ? 1.0 : 0.72)
                    .opacity(phase ? 1.0 : 0.45)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.12),
                        value: phase
                    )
            }
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { phase = true }
    }
}

struct MessageView: View {
    let text: String
    var body: some View {
        Group {
            if let attributed = try? AttributedString(markdown: text) { Text(attributed) }
            else { Text(text) }
        }
        .font(Typography.message)
        .foregroundStyle(Design.Foreground.primary)
        .lineSpacing(Spacing.lineSpacingMessage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .padding(.horizontal, 8)
    }
}

struct ReasoningView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typography.body.italic())
            .foregroundStyle(Design.Foreground.quaternary)
            .lineSpacing(Spacing.lineSpacingBody)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .padding(.leading, Spacing.quoteInset)
            .padding(.trailing, Spacing.quoteInset)
            .overlay(alignment: .leading) {
                Rectangle()
                    .offset(x: 12)
                    .fill(Design.Tint.artifact)
                    .frame(width: Spacing.quoteBarWidth)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
            }
    }
}

struct CodeBlock: View {
    let code: String
    
    var body: some View {
        Text(code)
            .font(Typography.mono)
            .foregroundStyle(Design.Foreground.caption)
            .lineSpacing(Spacing.lineSpacingMono)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .glassEffect(.regular, in:
                            RoundedRectangle(cornerRadius: Spacing.blockRadius)
            )
    }
}

struct ActionRow: View {
    let verb: String
    let name: String
    let output: String
    @State private var expanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Design.Tint.artifact)
                    Text(verb)
                        .font(Typography.body)
                        .foregroundStyle(Design.Foreground.tertiary)
                    Text(name)
                        .font(Typography.monoSmall)
                        .foregroundStyle(Design.Foreground.primary)
                    Spacer(minLength: 8)
                    if !output.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(Design.Foreground.tertiary)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(output.isEmpty)
            
            if expanded && !output.isEmpty {
                hairline().padding(.vertical, 7)
                Text(output)
                    .font(Typography.mono)
                    .foregroundStyle(Design.Foreground.caption)
                    .lineSpacing(Spacing.lineSpacingMono)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .event()
    }
}

struct StatusRow: View {
    let lines: [String]
    @State private var expanded = false
    
    private var earlier: [String] { Array(lines.dropLast()) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if expanded {
                ForEach(earlier.indices, id: \.self) { i in
                    statusLine(earlier[i]).opacity(0.85)
                }
            }
            Button {
                guard lines.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 7) {
                    statusDot
                    Text(lines.last ?? "")
                        .font(Typography.body)
                        .foregroundStyle(Design.Foreground.tertiary)
                    if lines.count > 1 {
                        Text("· +\(lines.count - 1) earlier")
                            .font(Typography.body)
                            .foregroundStyle(Design.Foreground.tertiary.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(lines.count <= 1)
        }
        .event()
    }
    
    private var statusDot: some View {
        Circle().fill(Design.Tint.artifact).frame(width: 3, height: 3)
    }
    
    private func statusLine(_ text: String) -> some View {
        HStack(spacing: 7) {
            statusDot
            Text(text).font(Typography.body).foregroundStyle(Design.Foreground.tertiary)
            Spacer(minLength: 0)
        }
    }
}

struct StateRow: View {
    let state: AgencyRuntime.Process.State
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.transcriptIcon)
                .font(.system(size: 12))
                .foregroundStyle(Design.Tint.blocked)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Design.Tint.blocked)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Spacing.blockRadius)
                .fill(Design.Tint.blocked.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.blockRadius)
                .stroke(Design.Tint.blocked.opacity(0.42), lineWidth: 0.5)
        )
    }
}

struct DomainRollup: View {
    let label: String
    let events: [String]
    @State private var expanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 10, weight: .light))
                        .foregroundStyle(Design.Tint.info)
                    Text(label)
                        .font(Typography.body)
                        .foregroundStyle(Design.Foreground.tertiary)
                    Text("· \(events.count) events")
                        .font(Typography.body)
                        .foregroundStyle(Design.Foreground.quaternary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Design.Foreground.quaternary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if expanded {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(events.indices, id: \.self) { i in
                        Text(events[i])
                            .font(Typography.body)
                            .foregroundStyle(Design.Foreground.tertiary)
                    }
                }
                .padding(.leading, 19)
            }
        }
        .event()
    }
}

struct TranscriptView: View {
    @Environment(AgencyModel.self) private var agency
    var ref: Reference? = nil
    private var transcript: Reference? {
        guard let selected = agency.session.selected.content, selected.type is Transcript.Type else { return ref }
        return ref ?? selected
    }
    var showStatus: Bool = true
    var showReasoning: Bool = true
    
    private var entries: [Transcript.Entry] {
        guard let transcript else { return [] }
        return Transcript.with(transcript, { $0.entries }) ?? []
    }
    
    private var active: Bool {
        guard let transcript else { return false }
        return Transcript.with(transcript, { $0.active }) ?? false
    }
    
    var body: some View {
        ScrollView {
            TranscriptEntriesView(
                entries: entries,
                showStatus: showStatus,
                showReasoning: showReasoning
            )
            .frame(maxWidth: 710, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
        }
        if active {
            TranscriptStatusIndicator().padding(.bottom, 8)
        }
    }
}

#Preview("Transcript rungs") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.blockSpacing) {
            DomainRollup(label: "composition", events: ["requested", "composed", "dispatching"])
            StatusRow(lines: ["processing", "traversing"])
            ReasoningView(text: "The property provider has to be rewired before the call sites move — otherwise the traversal resolves against the old surface.")
            ActionRow(
                verb: "ran",
                name: "git status",
                output: "On branch migrate/runtime-api\n  modified:  AgencyRuntime/Property.swift")
            MessageView(text: "The migration is mostly mechanical. I rewired `Property` to resolve through the runtime provider and updated the three call sites the traversal flagged. One ambiguity is left:")
            MessageView(text: "Do you want to keep the closure scope, or fall back to global for the legacy fixtures?")
            StateRow(state: .blocked, text: "blocked · awaiting input")
        }
        .frame(maxWidth: 700, alignment: .leading)
        .padding(15)
    }
    .frame(width: 480, height: 680)
    .background(Design.Background.base)
}
