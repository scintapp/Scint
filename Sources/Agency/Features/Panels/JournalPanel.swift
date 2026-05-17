import AgencyRuntime
import Foundation
import SwiftUI


struct NotesInputEntry<Content: View>: View {
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

struct JournalStatusIndicator: View {
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

struct JournalItem<Content: View>: View {
    let title: String
    let color: Color
    let systemImage: String
    let emphasis: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

struct JournalEvent: View {
    let event: Event

    var body: some View {
        switch event {
        case .message(_, let text):
            JournalItem(title: "Message", color: Design.Tint.info.opacity(0), systemImage: "text.bubble", emphasis: true) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }

        case .reasoning(_, let text):
            JournalItem(
                title: "Message",
                color: Design.Tint.info.opacity(0),
                systemImage: "text.bubble",
                emphasis: true
            ) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .opacity(0.9)
            }
        case .commandStarted(_, let command):
            JournalItem(
                title: "Command",
                color: Design.Tint.inactive,
                systemImage: "terminal",
                emphasis: false
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        Text(command)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        case .commandCompleted(_, let command, let output, _):
            JournalItem(
                title: "Command",
                color: Design.Tint.inactive,
                systemImage: "terminal",
                emphasis: false
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 12))
                        Text(command)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if !output.isEmpty {
                        Text(output)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
            }

        case .functionCall: EmptyView()
        case .functionResult: EmptyView()
        case .turnStarted: EmptyView()
        case .threadStarted: EmptyView()
        case .turnFailed: EmptyView()
        case .turnCompleted(_, _, _): EmptyView()

        case .unknown(let type, let raw):
            JournalItem(title: "Raw Event", color: Design.Tint.inactive, systemImage: "curlybraces", emphasis: false) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(type)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text((raw?.isEmpty == false ? raw : event.content) ?? event.content)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        default:
            JournalItem(title: "Event", color: Design.Tint.info.opacity(0), systemImage: "circle.dotted", emphasis: false) {
                Text(event.content)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

//struct JournalSheet: View {
//    let ref: Reference
//
//    var body: some View {
//        JournalItem(title: "Input", color: Design.Tint.info, systemImage: "square.and.pencil", emphasis: true) {
//            VStack(alignment: .leading, spacing: 8) {
//                Text(Sheet.with(ref, { $0.entries.map { $0.} }) ?? "")
//                    .font(.system(size: 14))
//                    .foregroundStyle(.primary)
//                    .textSelection(.enabled)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//}



//struct InputEntry<Content: View>: View {
//    let title: String
//    let systemImage: String
//    let emphasis: Bool
//    let color: Color
//
//    @ViewBuilder let content: Content
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            content
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(14)
//
//        .overlay {
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .strokeBorder(color.opacity(emphasis ? 0.08 : 0.05), lineWidth: 1)
//        }
//        .background(
//            RoundedRectangle(cornerRadius: 16, style: .circular)
//                .fill(color.opacity(0.03))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 16, style: .circular)
//                        .stroke(color.opacity(0.18), lineWidth: 0.5)
//                )
//        )
//    }
//}
//
//struct JournalStatusIndicator: View {
//    @State private var phase = false
//
//    var body: some View {
//        HStack(spacing: 7) {
//            ForEach(0..<3, id: \.self) { index in
//                Circle()
//                    .fill(.primary)
//                    .frame(width: 7, height: 7)
//                    .scaleEffect(phase ? 1.0 : 0.72)
//                    .opacity(phase ? 1.0 : 0.45)
//                    .animation(
//                        .easeInOut(duration: 0.8)
//                        .repeatForever(autoreverses: true)
//                        .delay(Double(index) * 0.12),
//                        value: phase
//                    )
//            }
//        }
//        .padding(.horizontal, 10)
//        .padding(.vertical, 10)
//        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
//        .onAppear { phase = true }
//    }
//}

//struct JournalItem<Content: View>: View {
//    let title: String
//    let color: Color
//    let systemImage: String
//    let emphasis: Bool
//    @ViewBuilder let content: Content
//
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            content
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding(14)
//        .background {
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .fill(color.opacity(emphasis ? 0.03 : 0.03))
//        }
//        .overlay {
//            RoundedRectangle(cornerRadius: 16, style: .continuous)
//                .strokeBorder(color.opacity(emphasis ? 0.15 : 0.1), lineWidth: 1)
//        }
//    }
//}
//
//struct JournalEvent: View {
//    let event: Event
//
//    var body: some View {
//        switch event {
//        case .message(_, let text):
//            JournalItem(title: "Message", color: Design.Tint.info.opacity(0), systemImage: "text.bubble", emphasis: true) {
//                Text(text)
//                    .font(.system(size: 14))
//                    .foregroundStyle(.primary)
//                    .textSelection(.enabled)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.vertical, 2)
//            }
//
//        case .reasoning(_, let text):
//            JournalItem(
//                title: "Message",
//                color: Design.Tint.info.opacity(0),
//                systemImage: "text.bubble",
//                emphasis: true
//            ) {
//                Text(text)
//                    .font(.system(size: 14))
//                    .foregroundStyle(.primary)
//                    .textSelection(.enabled)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.vertical, 2)
//                    .opacity(0.9)
//            }
//        case .commandStarted(_, let command):
//            JournalItem(
//                title: "Command",
//                color: Design.Tint.inactive,
//                systemImage: "terminal",
//                emphasis: false
//            ) {
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Image(systemName: "terminal")
//                            .foregroundStyle(.secondary)
//                            .font(.system(size: 12))
//                        Text(command)
//                            .font(.system(size: 11, design: .monospaced))
//                            .foregroundStyle(.secondary)
//                            .textSelection(.enabled)
//                    }
//                }
//            }
//        case .commandCompleted(_, let command, let output, _):
//            JournalItem(
//                title: "Command",
//                color: Design.Tint.inactive,
//                systemImage: "terminal",
//                emphasis: false
//            ) {
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Image(systemName: "terminal")
//                            .foregroundStyle(.secondary)
//                            .font(.system(size: 12))
//                        Text(command)
//                            .font(.system(size: 11, design: .monospaced))
//                            .foregroundStyle(.secondary)
//                            .textSelection(.enabled)
//                    }
//
//                    if !output.isEmpty {
//                        Text(output)
//                            .font(.system(size: 11, design: .monospaced))
//                            .foregroundStyle(.primary)
//                            .textSelection(.enabled)
//                    }
//                }
//            }
//
//        case .functionCall: EmptyView()
//        case .functionResult: EmptyView()
//        case .turnStarted: EmptyView()
//        case .threadStarted: EmptyView()
//        case .turnFailed: EmptyView()
//        case .turnCompleted(_, _, _): EmptyView()
//
//        case .unknown(let type, let raw):
//            JournalItem(title: "Raw Event", color: Design.Tint.inactive, systemImage: "curlybraces", emphasis: false) {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text(type)
//                        .font(.system(size: 11, weight: .semibold))
//                        .foregroundStyle(.secondary)
//
//                    Text((raw?.isEmpty == false ? raw : event.content) ?? event.content)
//                        .font(.system(size: 10.5, design: .monospaced))
//                        .foregroundStyle(.secondary)
//                        .textSelection(.enabled)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                }
//            }
//
//        default:
//            JournalItem(title: "Event", color: Design.Tint.info.opacity(0), systemImage: "circle.dotted", emphasis: false) {
//                Text(event.content)
//                    .font(.system(size: 11))
//                    .foregroundStyle(.secondary)
//                    .textSelection(.enabled)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//}
//
//struct JournalSheet: View {
//    let ref: Reference
//
//    var body: some View {
//        JournalItem(title: "Input", color: Design.Tint.info, systemImage: "square.and.pencil", emphasis: true) {
//            VStack(alignment: .leading, spacing: 8) {
//                Text(Sheet.with(ref, { $0.content }) ?? "")
//                    .font(.system(size: 14))
//                    .foregroundStyle(.primary)
//                    .textSelection(.enabled)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//}
//
//struct ComposePanel: View {
//    @Environment(AgencyModel.self) var agency
//
//    var body: some View {
//        ZStack(alignment: .bottom) {
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 12) {
//                    if let ref = agency.session.thread, let entries = Journal.with(ref, { $0 })?.entries {
//                        ForEach(entries) { event in
//                            switch event {
//                            case .event(_, let event, _): JournalEvent(event: event)
//                            case .sheet(let ref, _): JournalSheet(ref: ref)
//                            }
//                        }
//                    }
//                }
//                .frame(maxWidth: 700, maxHeight: .infinity, alignment: .center)
//            }
//        }
//        .padding(10)
//    }
//}
