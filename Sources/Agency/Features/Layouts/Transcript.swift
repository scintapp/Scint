import AgencyRuntime
import Foundation
import SwiftUI


struct TranscriptEntry: View {
    let entry: Transcript.Entry

    @ViewBuilder var body: some View {
        switch entry {
            case .input(let ref, _):
                let content = Sheet.with(ref, {
                    $0.rendered.trimmingCharacters(in: .whitespacesAndNewlines)
                })!
                HStack {
                    Spacer(minLength: 80)
                    Text(content)
                        .font(.system(size: 15))
                        .foregroundStyle(Design.Foreground.primary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Design.Shape.block.fill(Design.Background.block.opacity(0.72)))
                }

            case .transcript(let ref, _, _):
                let entries = Transcript.with(ref, { $0.entries })!
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(entries) { entry in
                        TranscriptEntry(entry: entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            case .event(let event, _, _):
                if let response = event.response {
                    let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    let text = (try? AttributedString(
                        markdown: content,
                        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    )) ?? AttributedString(content)

                    if !content.isEmpty {
                        switch response.kind {
                            case .message, .response:
                                Text(text)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Design.Foreground.primary)
                                    .lineSpacing(5)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 2)

                            case .reasoning:
                                Text(text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Design.Foreground.tertiary)
                                    .lineSpacing(4)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Design.Shape.block.fill(Design.Background.block.opacity(0.34)))

                            case .command, .function:
                                Text(content)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Design.Foreground.secondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Design.Shape.block.fill(Design.Background.console))

                            case .other(let type):
                                if type == "raw" || type.contains("error") || type.contains("fail") {
                                    Text(content)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Design.Foreground.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                        }
                    }
                } else {
                    switch event {
                        case .composing:
                            status("Composing")
                        case .dispatching:
                            status("Dispatching")
                        case .observing:
                            status("Observing")
                        case .processing:
                            status("Working")
                        case .traversing:
                            status("Traversing")
                        case .blocked:
                            status("Blocked")
                        case .failed:
                            status("Failed")
                        case .request, .updated, .completed, .properties:
                            EmptyView()
                    }
                }
        }
    }

    private func status(_ title: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Design.Foreground.quaternary)
            Rectangle()
                .fill(Design.Foreground.quaternary.opacity(0.2))
                .frame(height: 0.5)
        }
    }
}
