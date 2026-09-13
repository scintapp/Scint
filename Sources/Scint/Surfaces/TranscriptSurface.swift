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

            HStack(spacing: Style.Spacing.md) {
                Text(value.origin.type is Transcript.Type ? ref.descriptor.name : "Overview Transcript")
                    .font(Typography.row.weight(.semibold))
                    .foregroundStyle(Style.Foreground.muted)
                    .lineLimit(1)

                if let started = value.started {
                    Text(started, style: .time)
                }

                if elapsed > 0 {
                    Text(elapsed < 60 ? "\(elapsed)s" : "\(elapsed / 60)m \(elapsed % 60)s")
                }
            }
            .font(Typography.row)
            .foregroundStyle(Style.Foreground.faint)
            .frame(height: 24)
        }
    }
}

struct TranscriptSurface: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference {
        if let ref = model.session.opened.transcript { return ref }
        else if let ref = model.session.selection.content, ref.type is Transcript.Type { return ref }
        else { return model.session.space }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = min(Style.Dimension.transcriptMaxWidth, max(0, geometry.size.width - Style.Spacing.lg * 2))
            ScrollView {
                LazyVStack(spacing: Style.Spacing.transcriptEntrySpacing) {
                    if let transcript = model.session.transcript {
                        let records = (Transcript.with(transcript, { $0.entries }) ?? []).filter { entry in
                            if case .record = entry { true } else { false }
                        }

                        ForEach(records) { entry in
                            TranscriptEntry(
                                transcript: transcript,
                                entry: entry,
                                model: model,
                                inputMaxWidth: width * Style.Scale.transcriptInputWidth
                            )
                            .frame(maxWidth: Style.Dimension.transcriptMaxWidth)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(8)
            }
            .safeAreaBar(edge: .bottom) { TranscriptPicker(model: model) }
            .defaultScrollAnchor(.bottom, for: .initialOffset)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
        }
    }
}

