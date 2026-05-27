import AgencyRuntime
import Foundation
import SwiftUI


// MARK: - Containers (unchanged)

struct TranscriptInput<Content: View>: View {
    let title: String
    let systemImage: String
    let emphasis: Bool
    let color: Color

    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(emphasis ? 0.08 : 0.05), lineWidth: 1)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .circular)
                .fill(color.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .circular)
                        .stroke(color.opacity(0.18), lineWidth: 0.5)
                )
        )
    }
}

struct TranscriptStatusIndicator: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.primary)
                    .frame(width: 7, height: 7)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { phase = true }
    }
}

struct TranscriptItem<Content: View>: View {
    let title: String
    let color: Color
    let systemImage: String
    let emphasis: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(emphasis ? 0.03 : 0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(emphasis ? 0.15 : 0.1), lineWidth: 1)
        }
    }
}


// MARK: - Lifecycle beats
//
// The framework's own vocabulary. These are compact status rows — they say
// what happened, no payload. Provider output is handled separately below.

struct TranscriptBeat: View {
    let event: Event

    private var style: (title: String, icon: String, color: Color, emphasis: Bool) {
        switch event {
        case .composed:    return ("Composed",    "square.stack.3d.up", Design.Tint.info.opacity(0), false)
        case .request:     return ("Request",     "arrow.up.circle",    Design.Tint.info.opacity(0), false)
        case .dispatching: return ("Dispatching", "bolt",               Design.Tint.active, false)
        case .observing:   return ("Observing",   "eye",                Design.Tint.active, false)
        case .processing:  return ("Processing",  "gearshape.2",        Design.Tint.active, false)
        case .traversing:  return ("Traversing",  "arrow.triangle.branch", Design.Tint.active, false)
        case .progress:    return ("Progress",    "ellipsis",           Design.Tint.info.opacity(0), false)
        case .blocked:     return ("Blocked",     "pause.circle",       Design.Tint.info, true)
        case .completed:   return ("Completed",   "checkmark",          Design.Tint.info.opacity(0), false)
        case .failed:      return ("Failed",      "exclamationmark.triangle", Design.Tint.failed, true)
        case .provider:    return ("Output",      "text.bubble",        Design.Tint.info.opacity(0), true) // handled elsewhere
        }
    }

    var body: some View {
        let s = style
        TranscriptItem(title: s.title, color: s.color, systemImage: s.icon, emphasis: s.emphasis) {
            EmptyView()
        }
    }
}


// MARK: - Provider output
//
// `.provider(Properties)` beats parsed through ProviderEvent (Properties +
// keypaths). One view, switching on the coarse Kind tag.

struct TranscriptProviderEvent: View {
    let provider: ProviderEvent

    var body: some View {
        switch provider.kind {
        case .message:
            TranscriptItem(title: "Message", color: Design.Tint.info.opacity(0), systemImage: "text.bubble", emphasis: true) {
                bodyText(provider.text, size: 14)
            }

        case .reasoning:
            TranscriptItem(title: "Reasoning", color: Design.Tint.info.opacity(0), systemImage: "brain", emphasis: true) {
                bodyText(provider.text, size: 14).opacity(0.9)
            }

        case .command:
            TranscriptItem(title: "Command", color: Design.Tint.active, systemImage: "terminal", emphasis: false) {
                VStack(alignment: .leading, spacing: 8) {
                    if !provider.name.isEmpty {
                        HStack {
                            Image(systemName: "terminal")
                                .foregroundStyle(.secondary).font(.system(size: 12))
                            Text(provider.name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    if provider.text != provider.name, !provider.text.isEmpty {
                        Text(provider.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary).textSelection(.enabled)
                    }
                }
            }

        case .function:
            TranscriptItem(title: provider.name.isEmpty ? "Function" : provider.name, color: Design.Tint.service, systemImage: "function", emphasis: false) {
                Text(provider.text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .response:
            TranscriptItem(title: "Response", color: Design.Tint.info.opacity(0), systemImage: "text.bubble", emphasis: true) {
                bodyText(provider.text, size: 14)
            }

        case .other(let type):
            TranscriptItem(title: type.isEmpty ? "Event" : type, color: Design.Tint.active, systemImage: "curlybraces", emphasis: false) {
                Text(provider.text)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.secondary).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func bodyText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size))
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }
}

struct TranscriptResponse: View {
    let fragments: [String]

    private var output: String {
        fragments.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        TranscriptItem(title: "Response", color: Design.Tint.info.opacity(0), systemImage: "text.bubble", emphasis: true) {
            if output.isEmpty {
                Text("\(fragments.count) response events")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                Text(output)
                    .font(.system(size: 14)).foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
        }
    }
}

struct TranscriptSheet: View {
    let ref: Reference

    var body: some View {
        TranscriptItem(title: "Input", color: Design.Tint.info, systemImage: "square.and.pencil", emphasis: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Sheet.with(ref, { $0.content }) ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private enum TranscriptBlock: Identifiable {
    case beat(Event, UUID)
    case provider(ProviderEvent, UUID)
    case response([String], UUID)
    case sheet(Reference, UUID)
    case transcript(Reference, UUID)

    var id: UUID {
        switch self {
        case .beat(_, let id), .provider(_, let id), .response(_, let id),
             .sheet(_, let id), .transcript(_, let id): id
        }
    }

    static func blocks(from entries: [Transcript.Entry]) -> [TranscriptBlock] {
        var blocks: [TranscriptBlock] = []
        var deltas: [String] = []
        var deltaId: UUID?

        func flushDeltas() {
            guard !deltas.isEmpty else { return }
            blocks.append(.response(deltas, deltaId ?? UUID()))
            deltas.removeAll()
            deltaId = nil
        }

        for entry in entries {
            switch entry {
            case .event(let event, let id, _):
                if let provider = event.provider {
                    if provider.kind == .response {
                        if deltaId == nil { deltaId = id }
                        deltas.append(provider.text)
                    } else {
                        flushDeltas()
                        blocks.append(.provider(provider, id))
                    }
                } else {
                    flushDeltas()
                    blocks.append(.beat(event, id))
                }
            case .sheet(let ref, _):
                flushDeltas()
                blocks.append(.sheet(ref, entry.id))
            case .transcript(let ref, _, _):
                flushDeltas()
                blocks.append(.transcript(ref, entry.id))
            }
        }

        flushDeltas()
        return blocks
    }
}

struct TranscriptEntriesView: View {
    let entries: [Transcript.Entry]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(TranscriptBlock.blocks(from: entries)) { block in
                switch block {
                case .beat(let event, _):       TranscriptBeat(event: event)
                case .provider(let p, _):       TranscriptProviderEvent(provider: p)
                case .response(let frags, _):   TranscriptResponse(fragments: frags)
                case .sheet(let ref, _):        TranscriptSheet(ref: ref)
                case .transcript(let ref, _):   TranscriptNestedView(ref: ref)
                }
            }
        }
    }
}

struct TranscriptNestedView: View {
    let ref: Reference

    private var entries: [Transcript.Entry] {
        Transcript.with(ref, { $0.entries }) ?? []
    }

    var body: some View {
        TranscriptItem(title: Transcript.with(ref, { $0.name }) ?? "Transcript", color: Design.Tint.info, systemImage: "text.bubble", emphasis: false) {
            TranscriptEntriesView(entries: entries)
        }
    }
}

struct TranscriptView: View {
    @Environment(AgencyModel.self) var agency

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
                TranscriptEntriesView(entries: entries)
                    .frame(maxWidth: 700, maxHeight: .infinity, alignment: .center)
            }
            if active { TranscriptStatusIndicator().padding(.bottom, 8) }
        }
        .padding(10)
    }
}
