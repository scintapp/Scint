import ScintComponents
import SwiftUI


struct TranscriptHeader: View {
    var ref: Reference

    var body: some View {
        if let value = Transcript.with(ref, { $0 }) {
            let elapsed = if let started = value.started, let stopped = value.stopped {
                Int(stopped.timeIntervalSince(started).rounded())
            } else {
                0
            }

            HStack(spacing: Style.Spacing.label) {
                Text(value.origin.type is Transcript.Type ? ref.descriptor.name : "Overview Transcript")
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineLimit(1)

                if let started = value.started {
                    Text(started, style: .time)
                }

                if elapsed > 0 {
                    Text(elapsed < 60 ? "\(elapsed)s" : "\(elapsed / 60)m \(elapsed % 60)s")
                }
            }
            .font(Typography.body)
            .foregroundStyle(Style.Foreground.secondary)
            .frame(height: 24)
        }
    }
}

struct TranscriptSurface: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? {
        if let ref = model.session.opened.transcript { return ref }
        else if let ref = model.session.selection.content, ref.type is Transcript.Type { return ref }
        else { return nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            GeometryReader { geometry in
                ScrollView {
                    Color.clear.frame(height: 9)
                    LazyVStack(spacing: Style.Spacing.entry) {
                        if let transcript = model.session.transcript {
                            let records = (Transcript.with(transcript, { $0.entries }) ?? []).filter { entry in
                                if case .record = entry { true } else { false }
                            }

                            ForEach(records) { entry in
                                TranscriptEntry(transcript: transcript, entry: entry, model: model)
                                    .frame(maxWidth: Style.Prose.readableWidth)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(8)
                }
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .padding(.bottom, 24)
            }

            InputBar(model: model, onSend: {})
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, Style.Spacing.inset)
                .padding(.bottom, Style.Spacing.inset)

        }
    }
}

