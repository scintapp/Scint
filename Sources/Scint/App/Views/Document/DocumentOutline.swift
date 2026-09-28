import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct OutlineContext: View {
    var ref: Reference
    var model: any Model

    var references: [Reference] {
        let found = (ScintRuntime.Document.with(ref, { $0.blocks }) ?? []).flatMap { block -> [Reference] in
            switch block {
                case .artifact(let component), .command(let component), .document(let component): return [component]
                case .text(_, let text):
                    let source = text as NSString
                    return Markdown.scan(text).links.compactMap { Reference.Link.reference(in: source.substring(with: $0.url)) }
                case .data, .frame, .task: return []
            }
        }
        return found.reduce(into: [Reference]()) { if $1 != ref, !$0.contains($1) { $0.append($1) } }
    }

    var body: some View {
        if !references.isEmpty {
            Divider()

            DisclosureSection("Context", detail: "\(references.count)") {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(references) { reference in
                        let text = Card.text(for: reference)
                        let preview = reference.type is ScintRuntime.Document.Type ?

                        DocumentMapper.summary(reference) : text.description

                        Button { model.open(reference) } label: {
                            FileRow(text.name, path: preview, icon: Iconography.icon(for: reference))
                                .lineLimit(2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct OutlineTasks: View {
    var ref: Reference

    var tasks: [ScintRuntime.Document.Block] {
        Document.with(ref) { document in
            document.blocks.filter { if case .task = $0 { true } else { false } }
        } ?? []
    }

    var completed: Int { tasks.filter { if case .task(_, _, true, _) = $0 { true } else { false } }.count }

    var body: some View {
        if !tasks.isEmpty {
            Divider()

            DisclosureSection("Tasks", detail: "\(completed) of \(tasks.count)") {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        if case .task(let id, let text, let done, let when) = task {
                            ScintComponents.TaskRow(text, isDone: Binding(get: { done }, set: { value in
                                let block = ScintRuntime.Document.Block.task(id, text, value, when)
                                Document.update(ref) { document in
                                    if let index = document.blocks.firstIndex(where: { $0.id == block.id }) { document.update(block, at: index) }
                                }
                            }))
                        }
                    }
                }
                .controlSize(.small)
                .padding(.horizontal, -10)
            }
        }
    }
}

struct OutlineHeader: View {
    var ref: Reference
    var space: Reference
    var documents: [Reference]
    var panel: any Panel
    var model: any Model

    var harness: Reference? { Space.with(space, { $0.harness }) ?? nil }

    var body: some View {
        let summary = DocumentMapper.summary(ref)

        VStack(alignment: .leading, spacing: Style.Spacing.heading) {
            HStack(spacing: 8) {
                Group {
                    if let harness { Iconography.icon(for: harness, size: 13) }
                    else { Iconography.icon(for: space, size: 13) }
                }

                Text(space.descriptor.name)
                    .font(Typography.detail)
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                IconButton(systemImage: "arrow.up.right") { model.select(space) }
                    .controlSize(.small)
                    .foregroundStyle(Style.Foreground.secondary)
                    .help("Go to \(space.descriptor.name)")
            }

            SwiftUI.Menu {
                ForEach(documents) { document in
                    Toggle(isOn: .init(get: { document == ref }, set: { if $0 { panel.state["document", as: Reference.self] = document } })) {
                        Text(Card.text(for: document).name)
                    }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Card.text(for: ref).name)
                        .font(Typography.heading(2))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.down")
                        .font(Typography.detail.weight(.semibold))
                        .foregroundStyle(Style.Foreground.subtle)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)

            if !summary.isEmpty {
                Text((try? AttributedString(markdown: summary, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(summary))
                    .font(Typography.body)
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineSpacing(Typography.Prose.lineSpacing)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DocumentOutline: Surface {
    var panel: any Panel
    var model: any Model
    var surface: AnySurface { .init(panel: panel, model: model) }

    var library: Reference { model.session.library }

    var documents: [Reference] {
        guard let docs = Space.with(library, { $0.documents }) else { return [] }
        return docs.filter { $0.descriptor.tags.isDisjoint(with: ["input", "automation"]) }
    }

    var document: Reference? { panel.state["document", as: Reference.self] ?? documents.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Style.Spacing.page) {
                if let document {
                    OutlineHeader(ref: document, space: library, documents: documents, panel: panel, model: model)
                    OutlineTasks(ref: document)
                    OutlineContext(ref: document, model: model)
                }

                ForEach(ArtifactsGroup.parameters(model).sections) { section in
                    Factory.build(surface, params: section, controls: ArtifactsGroup.controls(model), layout: .group)
                }
            }
            .font(Typography.body)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(20)
        }
        .frame(maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onChange(of: library) { panel.state["document", as: Reference.self] = nil }
    }
}
