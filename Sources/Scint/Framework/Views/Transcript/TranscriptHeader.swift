import SwiftUI
import ScintRuntime
import ScintComponents


struct TranscriptHeader: View {
    var ref: Reference

    var body: some View {
        if let value = Transcript.with(ref, { $0 }) {
            let elapsed = if let started = value.started, let stopped = value.stopped {
                Int(stopped.timeIntervalSince(started).rounded())
            } else {
                0
            }

            HStack(spacing: 8) {
                Text(value.origin.type is Transcript.Type ? ref.descriptor.name : "Overview")
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
