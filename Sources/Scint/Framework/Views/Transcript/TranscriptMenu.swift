import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptMenu: Surface {
    var host: any Host
    var model: any Model

    @State private var selection: Reference?

    var space: Reference? { model.session.selection.structure }
    var transcripts: [Reference] { if let space { return Space.with(space, { $0 })?.transcripts ?? [] } else { return [] } }
    var documents: [Reference] { if let space { return Space.with(space, { $0 })?.documents ?? [] } else { return [] } }

    var ref: Reference? {
        if let selection, transcripts.contains(selection) { return selection }
        return transcripts.max { $0.descriptor.created < $1.descriptor.created }
    }

    var body: some View {
        if let ref {
            SwiftUI.Menu {
                ForEach(transcripts) { transcript in
                    Button {
                        selection = transcript
                        if !model.session.selection.selected(ref) { model.select(ref) }
                        model.select(transcript)
                    } label: {
                        if transcript == self.ref {
                            Label(transcript.descriptor.name, systemImage: "checkmark")
                        } else {
                            Text(transcript.descriptor.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Iconography.Icon(symbol: "text.bubble", tint: Style.Foreground.secondary, sizing: 16)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) {
                            Text(ref.descriptor.name)
                                let count = Transcript.with(ref, { $0.records.count }) ?? 0
                                Text("· \(count) \(count == 1 ? "message" : "messages")")
                                    .foregroundStyle(Style.Foreground.secondary)
                        }
                        .fixedSize()
                        Text(ref.descriptor.name)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                }
                .font(Typography.body)
                .foregroundStyle(Style.Foreground.primary)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(Style.Shape.control.fill(Style.Background.surface))
                .overlay(Style.Shape.control.strokeBorder(Style.Border.hairline, lineWidth: 1))
                .contentShape(Style.Shape.control)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .disabled(transcripts.isEmpty)
        }
    }
}
