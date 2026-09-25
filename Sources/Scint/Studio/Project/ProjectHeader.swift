import SwiftUI
import ScintComponents
import ScintRuntime


struct ProjectHeader: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.selection.structure }

    @Binding var presentation: ProjectContent.Presentation

    var body: some View {
        if let ref {
            HStack(alignment: .center, spacing: 16) {
                Iconography.icon(for: ref, size: 18)
                PageHeader(ref.descriptor.name) { }
                Spacer()
                SegmentedTabs(
                    selection: $presentation,
                    options: ProjectContent.Presentation.allCases,
                    image: \.image
                )
                IconButton(systemImage: "ellipsis") { }
            }
            .frame(maxWidth: .infinity, maxHeight: 40, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}
