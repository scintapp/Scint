import Foundation
import SwiftUI
import ScintComponents
import ScintRuntime


struct ProjectHeader: Surface {
    var host: any Host
    var model: any Model

    var ref: Reference? { model.session.selection.structure }

    @Binding var presentation: ProjectContent.Presentation

    var body: some View {
        if let ref {
            HStack(alignment: .center, spacing: 12) {
                Iconography.icon(for: ref, size: 18)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                Text(ref.descriptor.name)
                    .font(Typography.pageTitle)
                Spacer()
                SegmentedTabs(
                    selection: $presentation,
                    options: ProjectContent.Presentation.allCases,
                    image: \.image
                )
                IconButton(systemImage: "ellipsis", action: {})
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}
