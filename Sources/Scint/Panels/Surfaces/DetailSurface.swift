import SwiftUI


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
            } trailing: {}
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

            Divider()

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
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .background(Style.Shape.medium.fill(Style.Background.raised))
        .overlay(Style.Shape.medium.stroke(Style.Border.raised, lineWidth: 1))
    }
}


struct DetailSection<Content: View>: View {
    var title: String
    var count: Int
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            .background {
                Style.Shape.medium
                    .fill(Style.Background.raised)
                    .stroke(Style.Border.raised, lineWidth: 0.5, antialiased: true)
            }
    }
}

struct DetailSurface: Surface {
    var panel: any Panel
    var model: any Model

    var origin: Reference { model.session.origin }

    var materials: [Reference] {
        model.session.materials.filter {
            $0.descriptor.published != false && !$0.descriptor.tags.contains("input")
        }
    }

    var spaces: [Reference] {
        let refs = Space.with(origin, { Array($0.spaces) })
        ?? Workspace.with(origin, { Array($0.spaces) })
        ?? []

        return refs
            .filter { $0.descriptor.published != false }
            .sorted {
                $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending
            }
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
                DetailHeader(ref: origin)

                //                if !transcripts.isEmpty {
                //                    DetailSection(title: "Transcripts", count: transcripts.count) {
                //                        ForEach(transcripts) { transcript in
                //                            DetailRow(
                //                                ref: transcript,
                //                                detail: detail(for: transcript),
                //                                selected: model.session.transcript == transcript,
                //                                onSelect: {
                //                                    model.open(transcript)
                //                                    model.select(transcript)
                //                                }
                //                            )
                //                        }
                //                    }
                //                }

                if !spaces.isEmpty {
                    DetailSection(title: "Spaces", count: spaces.count) {
                        ForEach(spaces) { space in
                            DetailRow(
                                ref: space,
                                detail: space.descriptor.description,
                                selected: model.session.selected.selected(space),
                                onSelect: {
                                    model.select(space)
                                }
                            )
                        }
                    }
                }

                if !materials.isEmpty {
                    DetailSection(title: "Materials", count: materials.count) {
                        ForEach(materials) { material in
                            DetailRow(
                                ref: material,
                                detail: material.descriptor.description,
                                selected: model.session.material == material,
                                onSelect: {
                                    model.open(material)
                                    model.select(material)
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding([.horizontal, .top], 24)
        }
        .frame(maxWidth: 340, maxHeight: .infinity, alignment: .top)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
}
