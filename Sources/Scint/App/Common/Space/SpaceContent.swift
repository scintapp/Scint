import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SpaceContent: View {
    var ref: Reference

    var context: Context? { ref.context }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let context, let transcript = context.transcript {
                TranscriptContent(transcript: transcript)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            Rectangle()
                .fill(Style.Background.canvas)
                .frame(maxHeight: 64, alignment: .bottom)
                .blur(radius: 10, opaque: false)
                .blendMode(.darken)
                .padding(.bottom, -32)
        }
        .background(Style.Background.canvas)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
