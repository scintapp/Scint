import SwiftUI


struct DetailHeader: View {
    let ref: Reference

    var body: some View {
        let name = ref.descriptor.name
        let description = ref.descriptor.description

        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Iconography
                    .icon(for: ref, size: 16)
                    .frame(alignment: .leading)
                    .padding(.top, 10)
                    .padding(.trailing, 4)

                Text(name)
                    .frame(alignment: .leading)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Style.Foreground.base)
                    .padding(.top, 10)
            }

            VStack(alignment: .center) {
                Text(description.isEmpty ? "Add a description..." : description)
                    .frame(alignment: .leading)
                    .foregroundStyle(
                        description.isEmpty ? Style.Foreground.faint : Style.Foreground.subtle
                    )
                    .font(.system(size: 12))
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct DetailRow: View {
    @State private var isHovered = false
    var ref: Reference
    var detail: String
    var selected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            RowLayout(
                title: Text(ref.descriptor.name)
                    .font(Typography.row.weight(.medium))
                    .foregroundColor(Style.Foreground.base),
                detail: detail.isEmpty ? nil : Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(Style.Foreground.faint),
                detailLineLimit: 2,
                spacing: 10,
                spacerMinLength: 0
            ) {
                Iconography.icon(for: ref, size: 13)
                    .frame(width: 20, height: 20)
            } trailing: {

            }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    Style.Shape.medium
                        .fill(Style.Background.raised)
                        .stroke(Style.Border.raised, lineWidth: 0.5, antialiased: true)
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct DetailSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }
    var material: Reference? { model.session.opened.material }

    var spaces: [Reference] {
        guard let refs = Workspace.with(model.session.workspace, { Array($0.spaces) })
        else { return [] }
        return refs
    }

    func detail(for transcript: Reference) -> String {
        var calendar: Calendar { .autoupdatingCurrent }
        let date = transcript.descriptor.created
        let day: String
        if calendar.isDateInToday(date) { day = "Today" }
        else if calendar.isDateInYesterday(date) { day = "Yesterday" }
        else { day = date.formatted(.dateTime.month(.abbreviated).day()) }
        return "\(day), \(date.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !spaces.isEmpty {
                    ForEach(spaces) { space in
                        DetailRow(
                            ref: space,
                            detail: space.descriptor.description,
                            selected: model.session.selected.selected(space),
                            onSelect: { model.select(space) }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding([.horizontal, .top], 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scrollEdgeEffectStyle(.hard, for: .vertical)
    }
}
