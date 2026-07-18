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
                status(ref.descriptor.name)

            case .signal(let signal, _, _):
                switch signal {
                    case .trigger:
                        status("Triggered")
                    case .started(let ref):
                        status("Started \(ref.descriptor.name)")
                    case .updated(let value):
                        content(value)
                    case .completed:
                        status("Completed")
                    case .failed(let value):
                        content(value, failed: true)
                        status("Failed")
                }
        }
    }

    private func content(_ value: Value, failed: Bool = false) -> some View {
        let content = value.rendered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let text = (try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)

        return Text(text)
            .font(.system(size: 15))
            .foregroundStyle(failed ? Design.Foreground.secondary : Design.Foreground.primary)
            .lineSpacing(5)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
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
