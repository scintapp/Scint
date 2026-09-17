import SwiftUI
import Foundation


struct NewDraftButton: View {
    var panel: any Panel
    var model: any Model

    var drafts: Reference { model.session.drafts }

    var body: some View {
        Button {
            model.open(Material.new(drafts, name: "New Draft"))
            panel.state.presented.toggle()
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .sheet(isPresented: panel.bindable.presented) {
            if let material = model.session.opened.material {
                DraftSurface(model: model, material: material)
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .scrollIndicators(.hidden)
                    .background(Style.Background.base)
                    .frame(width: 660, height: 380)
                    .presentationSizing(.fitted)

            }
        }
    }
}

struct DraftCard: View {
    let ref: Reference
    let selected: Bool

    var blocks: [Material.Block] { Material.with(ref, { $0.blocks }) ?? [] }

    var body: some View {
        VStack(spacing: Style.Spacing.sm) {
            VStack(alignment: .leading, spacing: Style.Spacing.sm) {
                ForEach(blocks.prefix(6)) { MaterialBlock(block: $0) }
            }
            .padding(Style.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220, alignment: .topLeading)
            .clipShape(Style.Shape.medium)
            .background(Style.Shape.medium.fill(Style.Background.card))
            .overlay(Style.Shape.medium.stroke(selected ? Style.Tint.accent : Style.Border.card, lineWidth: selected ? 2 : 1))

            Text(ref.descriptor.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Text(ref.descriptor.updated.formatted(date: .numeric, time: .omitted))
                .font(.system(size: 11))
                .foregroundStyle(Style.Foreground.secondary)
        }
    }
}

struct DraftSurface: View {
    var model: any Model
    var material: Reference

    var drafts: Reference { model.session.drafts }

    var body: some View {
        ScrollView {
            EditorView(
                material,
                sizing: .fitsContent,
                autofocus: true,
                onFocus: { model.open(material) },
            )
            .id(material)
            .frame(maxWidth: Style.Spacing.contentMaxWidth, alignment: .center)
            .padding(.horizontal, Style.Spacing.xxl)
            .padding(.top, Style.Spacing.xxl)
            .padding(.bottom, Style.Spacing.xxxl)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .background(Style.Background.base)
    }
}

struct DraftsSurface: Surface {
    var panel: any Panel
    var model: any Model

    var drafts: [Reference] {
        (Space.with(model.session.drafts, { $0 })?.materials ?? [])
            .sorted { $0.descriptor.updated > $1.descriptor.updated }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: Style.Spacing.xxl)], spacing: Style.Spacing.xxl) {
                ForEach(drafts) { ref in
                    DraftCard(ref: ref, selected: model.session.selection.selected(ref))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            model.open(ref)
                            panel.state.presented = true
                        }
                        .onTapGesture { model.select(ref) }
                }
            }
            .padding(Style.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            if let ref = model.session.selection.content { model.session.close(ref) }
        }
        .background(Style.Background.base)
    }
}



