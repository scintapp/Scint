import AgencyRuntime
import Foundation
import SwiftUI


//  Transcript.swift
//
//  The assembly layer. Reads live entries through the same handlers the old
//  module used (`Transcript.with`, `Sheet.with`) and groups them into the
//  finalized design-language rungs defined in Design.swift:
//
//      MessageView · ReasoningView · ActionRow · StatusRow · DomainRollup · StateRow
//
//  There is no `[Event]` projection and no value-model wrapper — `TranscriptBlock`
//  is the same grouping pass as before, just retargeted. It carries your native
//  types (Event, ProviderEvent, Reference) and exists only to coalesce runs
//  (response deltas, status, domain) before they render.


// MARK: - Grouping

private enum TranscriptBlock: Identifiable {
    case message(String, UUID)                                  // coalesced .response deltas / .message
    case reasoning(String, UUID)
    case action(verb: String, name: String, output: String, UUID) // .command / .function
    case status([String], UUID)                                 // coalesced lifecycle noise
    case domain(label: String, events: [String], UUID)          // rolled-up request/composed/completed
    case state(Composition.State, String, UUID)                 // promoted blocked / failed
    case input(Reference, UUID)                                 // .sheet
    case nested(Reference, UUID)                                // .transcript

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
                if let provider = event.provider {
                    switch provider.kind {
                    case .response:                              // stream — coalesce into one message
                        flushStatus(); flushDomain()
                        if deltaID == nil { deltaID = id }
                        deltas.append(provider.text)

                    case .message:                              // discrete message — its own spine block
                        flushAll()
                        let text = provider.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty { blocks.append(.message(text, id)) }

                    case .reasoning:
                        flushAll()
                        blocks.append(.reasoning(provider.text, id))

                    case .command:
                        flushAll()
                        let output = trimmingLeadingLine(provider.text, equalTo: provider.name)
                        blocks.append(.action(verb: "ran", name: provider.name, output: output, id))

                    case .function:
                        flushAll()
                        blocks.append(.action(verb: "called",
                                              name: provider.name.isEmpty ? "function" : provider.name,
                                              output: provider.text, id))

                    case .other:                                // unrecognized → falls through to status
                        flushMessage(); flushDomain()
                        if statusID == nil { statusID = id }
                        status.append(provider.text.isEmpty ? "event" : provider.text)
                    }
                } else {
                    switch event {
                    case .request, .composed, .completed:        // domain — rolled up
                        flushMessage(); flushStatus()
                        if domainID == nil { domainID = id }
                        domain.append(event.transcriptLabel)

                    case .dispatching, .observing, .processing, .traversing, .progress: // status — recessed
                        flushMessage(); flushDomain()
                        if statusID == nil { statusID = id }
                        status.append(event.transcriptLabel)

                    case .blocked:                               // promoted inline
                        flushAll()
                        blocks.append(.state(.blocked, "blocked · awaiting input", id))

                    case .failed:
                        flushAll()
                        blocks.append(.state(.failed, "failed", id))

                    case .provider:
                        break                                    // handled in the provider branch above
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

    /// Command output arrives as "cmd\noutput"; the cmd is already the row name,
    /// so peel it off and keep only the output for the expansion.
    private static func trimmingLeadingLine(_ text: String, equalTo name: String) -> String {
        guard !name.isEmpty, text.hasPrefix(name) else { return text }
        return String(text.dropFirst(name.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Event {
    /// Legible label for the recessed rungs — plain words, not wire names.
    var transcriptLabel: String {
        switch self {
        case .request:     return "requested"
        case .composed:    return "composed"
        case .dispatching: return "dispatching"
        case .observing:   return "observing"
        case .processing:  return "processing"
        case .traversing:  return "traversing"
        case .progress:    return "working"
        case .completed:   return "completed"
        case .blocked:     return "blocked"
        case .failed:      return "failed"
        case .provider(let properties): return ProviderEvent(properties).text
        }
    }
}


// MARK: - Entries

struct TranscriptEntriesView: View {
    let entries: [Transcript.Entry]
    var showStatus: Bool = true
    var showReasoning: Bool = true

    var body: some View {
        LazyVStack(alignment: .leading, spacing: TranscriptMetric.blockSpacing) {
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


// MARK: - Input (sheet)

struct TranscriptInputView: View {
    let ref: Reference

    private var content: String { Sheet.with(ref, { $0.content }) ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.pencil").font(.system(size: 10, weight: .light))
                Text("Input").font(TranscriptType.label)
            }
            .foregroundStyle(TranscriptTheme.textTertiary)

            Text(content)
                .font(TranscriptType.message)
                .foregroundStyle(TranscriptTheme.textSecondary)
                .lineSpacing(TranscriptMetric.lineSpacingMessage)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, TranscriptMetric.blockPaddingV)
        .padding(.horizontal, TranscriptMetric.blockPaddingH)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TranscriptTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: TranscriptMetric.blockRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TranscriptMetric.blockRadius, style: .continuous)
                .stroke(TranscriptTheme.border, lineWidth: 1)
        }
    }
}


// MARK: - Nested transcript

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
                Text(name).font(TranscriptType.label)
            }
            .foregroundStyle(TranscriptTheme.textTertiary)

            // Nest as a sub-thread (a left rule) rather than a block inside a block,
            // so depth never compounds the fills.
            TranscriptEntriesView(entries: entries, showStatus: showStatus, showReasoning: showReasoning)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(TranscriptTheme.border).frame(width: 1)
                }
        }
    }
}


// MARK: - Live status indicator

struct TranscriptStatusIndicator: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(TranscriptTheme.textTertiary)
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
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { phase = true }
    }
}


// MARK: - Transcript

struct TranscriptView: View {
    @Environment(AgencyModel.self) private var agency

    var showStatus: Bool = true
    var showReasoning: Bool = true

    private var transcript: Reference? { agency.session.transcript }

    private var entries: [Transcript.Entry] {
        guard let transcript else { return [] }
        return Transcript.with(transcript, { $0.entries }) ?? []
    }

    private var active: Bool {
        guard let transcript else { return false }
        return Transcript.with(transcript, { $0.active }) ?? false
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                TranscriptEntriesView(entries: entries,
                                      showStatus: showStatus,
                                      showReasoning: showReasoning)
                    .frame(maxWidth: 700, alignment: .leading)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
            }
            if active {
                TranscriptStatusIndicator().padding(.bottom, 8)
            }
        }
        .background(TranscriptTheme.base)
    }
}


// MARK: - Preview (rungs only — the live view needs AgencyModel)

#Preview("Transcript rungs") {
    ScrollView {
        VStack(alignment: .leading, spacing: TranscriptMetric.blockSpacing) {
            DomainRollup(label: "composition", events: ["requested", "composed", "dispatching"])
            StatusRow(lines: ["processing", "traversing"])
            ReasoningView(text: "The property provider has to be rewired before the call sites move — otherwise the traversal resolves against the old surface.")
            ActionRow(verb: "ran", name: "git status",
                      output: "On branch migrate/runtime-api\n  modified:  AgencyRuntime/Property.swift")
            MessageView(text: "The migration is mostly mechanical. I rewired `Property` to resolve through the runtime provider and updated the three call sites the traversal flagged. One ambiguity is left:")
            MessageView(text: "Do you want to keep the closure scope, or fall back to global for the legacy fixtures?")
            StateRow(state: .blocked, text: "blocked · awaiting input")
        }
        .frame(maxWidth: 700, alignment: .leading)
        .padding(15)
    }
    .frame(width: 480, height: 680)
    .background(TranscriptTheme.base)
}
