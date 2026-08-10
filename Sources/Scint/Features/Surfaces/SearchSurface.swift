import SwiftUI


struct hostRow: View {
    let name: String
    let description: String
    let image: String
    let tint: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Iconography.Icon(
                symbol: image.isEmpty ? "square.stack.3d.up" : image,
                tint: tint,
                sizing: 20,
                selected: isSelected
            )
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.leading, 2)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(
                        isSelected
                        ? Design.Foreground.primary
                        : Design.Foreground.secondary
                    )
                    .lineLimit(1)

                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Foreground.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .padding(.trailing, 8)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.Foreground.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    isSelected
                    ? Design.Foreground.accent.opacity(0.6)
                    : Color.clear
                )
        )
    }
}

struct hostInput: View {
    @Binding var value: String
    @FocusState var focused: Bool

    let image: String
    let placeholder: String
    var onUpArrow: () -> KeyPress.Result = { .ignored }
    var onDownArrow: () -> KeyPress.Result = { .ignored }
    var onReturn: () -> KeyPress.Result = { .ignored }
    var onTab: () -> KeyPress.Result = { .ignored }

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: image)
                    .frame(height: 48, alignment: .center)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 26, weight: .light))

                TextField(placeholder, text: $value)
                    .frame(height: 48, alignment: .center)
                    .padding(.bottom, 2)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 28, weight: .light))
                    .textFieldStyle(.plain)
                    .onKeyPress(.upArrow) { onUpArrow() }
                    .onKeyPress(.downArrow) { onDownArrow() }
                    .onKeyPress(.return) { onReturn() }
                    .onKeyPress(.tab) { onTab() }
                    .focused($focused)
            }
            .frame(height: 48)

            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .padding(.horizontal, 4)
                .opacity(0.17)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .onAppear { focused = true }
        .onChange(of: placeholder) { _, _ in focused = true }
    }
}

struct SearchSurface: Surface {
    var host: any Host
    let model: any Model

    private var search: SearchPanel { host as! SearchPanel }

    var body: some View {
        let search = self.search
        let params = host.parameters(model)
        let controls = host.controls(model)
        let items = params.components.flatMap(\.items)
        let surfaces = params.panel?.items ?? []
        let selection = params.panel?.selection
        let surfaceIndex = surfaces.firstIndex { $0.id == selection?.id } ?? 0

        func move(_ delta: Int) {
            guard !items.isEmpty else { return }
            host.state.index = (host.state.index + delta + items.count) % items.count
        }

        func commit() {
            guard items.indices.contains(host.state.index) else { return }
            let item = items[host.state.index]
            if let onAction = controls.onAction { onAction(item) }
            else { controls.onSelect?(item) }
        }

        func selectSurface(_ index: Int) {
            guard surfaces.indices.contains(index) else { return }
            let target = surfaces[index]
            controls.onChange?(selection ?? target, target)
        }

        func cycleSurface() -> KeyPress.Result {
            guard surfaces.count > 1 else { return .ignored }
            selectSurface((surfaceIndex + 1) % surfaces.count)
            return .handled
        }

        return VStack(alignment: .leading, spacing: 0) {
            if let input = params.panel?.input {
                hostInput(
                    value: Binding(
                        get: { host.state.query },
                        set: { controls.onValueChange?(input, $0) }
                    ),
                    image: input.image,
                    placeholder: input.name,
                    onUpArrow: { move(-1); return .handled },
                    onDownArrow: { move(+1); return .handled },
                    onReturn: { commit(); return .handled },
                    onTab: cycleSurface
                )
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(params.components.enumerated()), id: \.element.id) { componentIndex, component in
                            if !component.items.isEmpty {
                                if component.header && !component.name.isEmpty {
                                    Text(component.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.top, 12)
                                        .padding(.bottom, 6)
                                }

                                let startIndex = params.components.prefix(componentIndex).reduce(0) { $0 + $1.items.count }
                                ForEach(Array(component.items.enumerated()), id: \.element.id) { offset, item in
                                    let absoluteIndex = startIndex + offset
                                    hostRow(
                                        name: item.name,
                                        description: item.description,
                                        image: item.image,
                                        tint: item.tint ?? Design.Tint.active,
                                        isSelected: absoluteIndex == host.state.index,
                                        onTap: {
                                            host.state.index = absoluteIndex
                                            controls.onSelect?(item)
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: host.state.index) { _, newIndex in
                    guard items.indices.contains(newIndex) else { return }
                    proxy.scrollTo(items[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: host.state.query) { _, _ in host.state.index = 0 }
        .onChange(of: search.mode) { _, _ in host.state.index = 0 }
        .background {
            ZStack {
                ForEach(0..<min(surfaces.count, 9), id: \.self) { index in
                    Button { selectSurface(index) } label: { EmptyView() }
                        .keyboardShortcut(
                            KeyEquivalent(Character(String(index + 1))),
                            modifiers: .command
                        )
                }
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }
}




//
//struct SpaceHeader: View {
//    var model: any Model
//
//    var origin: Reference { model.session.origin }
//    var context: Composition? { origin.context }
//
//    var body: some View {
//        Spacer().frame(height: Spacing.blockSpacing * 2)
//        HStack(alignment: .top, spacing: Spacing.blockSpacing * 2) {
//            VStack(alignment: .leading, spacing: Spacing.blockSpacing) {
//                Text(origin.descriptor.name)
//                    .font(.title.weight(.semibold))
//                    .foregroundStyle(Design.Foreground.primary)
//                if !origin.descriptor.description.isEmpty {
//                    Text(origin.descriptor.description)
//                        .font(Typography.body)
//                        .foregroundStyle(Design.Foreground.secondary)
//                        .lineLimit(2)
//                }
//            }
//            .frame(maxWidth: 520, alignment: .leading)
//
//            Spacer(minLength: 24)
//
//            VStack(alignment: .trailing, spacing: Spacing.blockSpacing) {
//                HStack(spacing: Spacing.messageExtraSpacing) {
//                    switch context?.state {
//                        case .running:
//                            Image(systemName: "circle.fill")
//                                .font(.system(size: 7))
//                                .foregroundStyle(Design.Tint.running)
//                            Text("Running")
//                                .fontWeight(.medium)
//                                .foregroundStyle(Design.Foreground.primary)
//
//                        case .active:
//                            Image(systemName: "circle.fill")
//                                .font(.system(size: 7))
//                                .foregroundStyle(Design.Tint.active)
//                            Text("Active")
//                                .fontWeight(.medium)
//                                .foregroundStyle(Design.Foreground.primary)
//
//                        case .inactive, nil:
//                            Image(systemName: "circle.fill")
//                                .font(.system(size: 7))
//                                .foregroundStyle(Design.Tint.inactive)
//                            Text("Ready")
//                                .fontWeight(.medium)
//                                .foregroundStyle(Design.Foreground.primary)
//                    }
//
//                    if let transcript = context?.intentTranscript {
//                        Text("·")
//                            .foregroundStyle(Design.Foreground.quaternary)
//                        Text(transcript.descriptor.name)
//                            .foregroundStyle(Design.Foreground.secondary)
//                            .lineLimit(1)
//                    }
//                }
//                .font(Typography.body)
//
//                HStack(spacing: Spacing.messageExtraSpacing) {
//                    Text("\(context?.intents.count ?? 0) active")
//
//                    if let details = Space.with(origin, { space in
//                        Group {
//                            Text("·")
//                            Text("\(space.scenes.filter { $0.descriptor.published != false }.count) contents")
//                            Text("·")
//                            Text("\(space.spaces.filter { $0.descriptor.published != false }.count) spaces")
//
//                            if let harness = space.harness {
//                                Text("·")
//                                HStack(spacing: 5) {
//                                    Iconography.icon(for: harness, size: 10)
//                                    Text(harness.descriptor.name)
//                                }
//                            }
//                        }
//                    }) {
//                        details
//                    }
//                }
//                .font(Typography.body)
//                .foregroundStyle(Design.Foreground.tertiary)
//                .lineLimit(1)
//            }
//            .frame(maxWidth: 520, alignment: .trailing)
//        }
//        .frame(maxWidth: .infinity)
//    }
//}
//
//struct SpaceContent: Surface {
//    var host: any Host
//    var model: any Model
//    var ref: Reference? = nil
//
//    var body: some View {
//        VStack(alignment: .leading) {
//            ScrollView(.horizontal) {
//                let surface = AnySurface(host: host, model: model)
//                let parameters = if let ref { SpaceGrid.content(ref) } else { host.parameters(model) }
//                surface.render(surface, parameters, host.controls(model))
//                    .scrollDisabled(true)
//            }
//        }
//        .frame(maxWidth: .infinity, maxHeight: 144, alignment: .topLeading)
//    }
//}
//
//struct SpaceSurface: Surface {
//    var host: any Host
//    var model: any Model
//
//    var origin: Reference { model.session.origin }
//    var context: Composition? { origin.context }
//    var transcript: Reference? {
//        if let context { return context.transcript }
//
//        return Runtime.shared.transcripts(for: origin)
//            .filter { ref in
//                Transcript.with(ref) { transcript in
//                    transcript.entries.contains { entry in
//                        guard case .event(_, .composed(let source), _) = entry else { return false }
//                        return source == origin
//                    }
//                } == true
//            }
//            .min { $0.descriptor.created < $1.descriptor.created }
//    }
//    var active: Bool? { context?.state == .active }
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: Spacing.blockSpacing * 2) {
//                SpaceHeader(model: model)
//
//                VStack(alignment: .leading, spacing: Spacing.blockSpacing) {
//                    Text("Contents")
//                        .font(.title2.weight(.medium))
//                        .foregroundStyle(Design.Foreground.primary)
//
//                    SpaceContent(host: host, model: model)
//                }
//
//                VStack(alignment: .leading, spacing: Spacing.blockSpacing) {
//                    Text("Activity")
//                        .font(.title2.weight(.medium))
//                        .foregroundStyle(Design.Foreground.primary)
//
//                    if let transcript,
//                       let activity = Transcript.with(transcript, { transcript in
//                           LazyVStack(alignment: .leading, spacing: Spacing.blockSpacing * 2) {
//                               ForEach(transcript.entries) { entry in
//                                   TranscriptEntry(entry: entry)
//                               }
//                           }
//                           .frame(maxWidth: .infinity, alignment: .topLeading)
//                       }) {
//                        activity
//                    }
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .topLeading)
//            .padding(.bottom, Spacing.blockSpacing * 2)
//        }
//        .scrollEdgeEffectStyle(.soft, for: .top)
//    }
//}
