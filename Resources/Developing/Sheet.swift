import AgencyRuntime
import SwiftUI


//struct SheetView: View {
//    var entry: Sheet.Entry
//
//    private func control(_ ref: Reference) -> some View {
//        let name = Control.with(ref, { $0.name }) ?? "tool"
//        let args = Artifact.with(ref, { $0.content }) ?? ""
//
//        return EntryCard(icon: Design.Component.icon(for: ref), label: "Control") {
//            HStack(spacing: 10) {
//                EntryGlyph(icon: Design.Component.icon(for: ref))
//                EntryTextBlock(title: name, detail: args, design: .default)
//                Spacer(minLength: 10)
//                GhostButton(label: "Run", icon: "play.fill")
//            }
//        }
//    }
//
//    private func service(_ ref: Reference) -> some View {
//        let name = Harness.with(ref, { $0.name }) ?? "Harness"
//        let subtitle = Harness.with(ref, { $0.entries.compactMap(\.rendered).joined(separator: " ") }) ?? ""
//
//        return EntryCard(icon: Design.Component.icon(for: ref), label: "Harness") {
//            HStack(spacing: 10) {
//                EntryGlyph(icon: Design.Component.icon(for: ref))
//                EntryTextBlock(title: name, detail: subtitle)
//                Spacer(minLength: 10)
//                StatusPill(label: "Connected")
//            }
//        }
//    }
//
//    private func file(_ ref: Reference) -> some View {
//        let name = Artifact.with(ref, { $0.name }) ?? "file"
//        let meta = Artifact.with(ref, { $0.content }) ?? ""
//
//        return EntryCard(icon: Design.Component.icon(for: ref), label: "File") {
//            HStack(spacing: 10) {
//                EntryGlyph(icon: Design.Component.icon(for: ref))
//                EntryTextBlock(title: name, detail: meta, design: .default)
//                Spacer(minLength: 10)
//                GhostButton(label: "Open")
//            }
//        }
//    }
//
//    private func link(_ ref: Reference) -> some View {
//        let name = Artifact.with(ref, { $0.name }) ?? "Link"
//        let url = Artifact.with(ref, { $0.content }) ?? ""
//
//        return EntryCard(icon: Design.Component.icon(for: ref), label: "Link") {
//            HStack(spacing: 10) {
//                EntryGlyph(icon: Design.Component.icon(for: ref))
//                EntryTextBlock(title: name, detail: url, design: .default, truncation: .middle)
//                Spacer(minLength: 10)
//                GhostButton(label: "Open", icon: "arrow.up.right")
//            }
//        }
//    }
//
//    private func image(_ ref: Reference) -> some View {
//        let name = Artifact.with(ref, { $0.name }) ?? "image"
//
//        return EntryCard(icon: Design.Component.icon(for: ref), label: "Image") {
//            HStack(spacing: 10) {
//                EntryGlyph(icon: Design.Component.icon(for: ref))
//                EntryTextBlock(title: name, detail: nil)
//                Spacer(minLength: 10)
//                GhostButton(label: "View")
//            }
//        }
//    }
//
//    private func sheet(_ ref: Reference) -> some View {
//        let name = Sheet.with(ref, { $0.name }) ?? "Sheet"
//
//        return EntryCard(icon: Design.Component.icon(for: ref), label: "Sheet") {
//            HStack(spacing: 10) {
//                EntryGlyph(icon: Design.Component.icon(for: ref))
//                EntryTextBlock(title: name, detail: nil)
//                Spacer(minLength: 10)
//                GhostButton(label: "Open")
//            }
//        }
//    }
//
//    private func text(_ content: String) -> some View {
//        var trimmed: String { content.trimmingCharacters(in: .whitespacesAndNewlines) }
//        var looksLikeBlock: Bool { content.contains("\n") && (trimmed.contains("- ") || trimmed.hasPrefix("##")) }
//        var isHeading: Bool { !trimmed.contains("\n") && trimmed.hasPrefix("#") }
//        var isQuote: Bool { trimmed.hasPrefix(">") }
//        var quotePrefix: String { ">" }
//
//        var attributed: AttributedString {
//            (try? AttributedString(
//                markdown: trimmed,
//                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
//            )) ?? AttributedString(trimmed)
//        }
//
//        func stripped(_ prefix: String) -> String {
//            var s = trimmed
//            while s.hasPrefix(prefix) || s.hasPrefix(" ") {
//                if s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
//                else { s.removeFirst() }
//            }
//            return s
//        }
//
//        return VStack {
//            if looksLikeBlock {
//                Text(content)
//                    .font(.system(size: 11.5, design: .monospaced))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                    .lineSpacing(4)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(12)
//                    .background(Design.SheetEntry.codeBlockBg)
//                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 10, style: .continuous)
//                            .strokeBorder(Design.SheetEntry.stroke, lineWidth: 1)
//                    )
//            } else if isQuote {
//                HStack(spacing: 0) {
//                    Rectangle()
//                        .fill(Design.SheetEntry.accent)
//                        .frame(width: 3)
//                    Text(stripped(quotePrefix))
//                        .font(.system(size: 13, weight: .regular))
//                        .italic()
//                        .foregroundStyle(Design.SheetEntry.textSecondary)
//                        .lineSpacing(4)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .padding(.leading, 12)
//                }
//            } else if isHeading {
//                Text(stripped("#"))
//                    .font(.system(size: 16, weight: .semibold))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            } else {
//                Text(attributed)
//                    .font(.system(size: 13))
//                    .foregroundStyle(Design.SheetEntry.textPrimary)
//                    .lineSpacing(4)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//
//    private func todo(_ content: String, _ completed: Bool) -> some View {
//        EntryCard(icon: Design.Component.icon(for: entry), label: "Task") {
//            HStack(spacing: 10) {
//                EntryGlyph(icon: Design.Component.icon(for: entry))
//
//                Text(content)
//                    .font(.system(size: TypeScale.cardTitle, weight: .medium))
//                    .foregroundStyle(completed ? Design.SheetEntry.textTertiary : Design.SheetEntry.textPrimary)
//                    .strikethrough(completed, color: Design.SheetEntry.textTertiary)
//                    .lineLimit(2)
//
//                Spacer(minLength: 10)
//            }
//        }
//    }
//
//    var body: some View {
//        switch entry {
//        case .artifact(let ref):
//            switch Artifact.with(ref, { $0.entry }) {
//            case .app, .http, .script, .skill: link(ref)
//            case .exec, .file: file(ref)
//            case .image: image(ref)
//            default: link(ref)
//            }
//        case .control(let ref): control(ref)
//        case .service(let ref): service(ref)
//        case .sheet(let ref): sheet(ref)
//        case .content(_, let content): text(content)
//        case .task
            sheet.add(_, let content, let completed): todo(content, completed)
//        }
//    }
//}
