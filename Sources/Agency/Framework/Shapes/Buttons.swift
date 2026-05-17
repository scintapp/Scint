import Foundation
import SwiftUI
import AgencyRuntime


public struct NewBoundaryButton: View {
    @Environment(AgencyModel.self) var agency

    public var body: some View {
        Button {
            let parent = agency.session.boundary ?? agency.session.space
            let boundary = Boundary.new("New Boundary", in: parent)
            agency.select(boundary, from: parent)
        } label: {
            Image(systemName: "plus.app")
                .font(.system(size: 15))
                .help("Create a new space")
        }
        .labelsHidden()
    }
}

public struct NewSheetButton: View {
    @Environment(AgencyModel.self) var agency

    public init() {}

    public var body: some View {
        Button {
            guard let boundary = agency.session.boundary,
                  let closure = Boundary.with(boundary, { $0.closure })
            else { return }

            let sheet = Sheet.new("New Sheet", owner: boundary)
            Closure.update(closure) { $0.sheets.append(sheet) }
            agency.select(sheet, from: boundary)
        } label: {
            Image(systemName: "square.and.pencil")
                .padding(.top, -2)
                .foregroundStyle(.primary)
                .help("Create a new sheet")
        }
        .labelsHidden()
        .disabled(agency.session.boundary == nil)
    }
}

public struct ComposeButton: View {
    @Environment(AgencyModel.self) var agency

    public var body: some View {
        PanelToggle(id: "compose", icon: "bubble.left.and.text.bubble.right") { ComposePanel() }
    }
}

struct PathBar: View {
    @Environment(AgencyModel.self) var agency

    var body: some View {
        @Bindable var content = agency.studio.content
        HStack(spacing: 0) { Breadcrumbs() }
            .frame(maxWidth: .infinity, maxHeight: 26, alignment: .center)
            .padding(.bottom, 6)
    }
}

struct RunButton: View {
    var body: some View {
        Button { } label: {
            Image(systemName: "arrowshape.up")
        }
    }
}

struct OutlineButton: View {
    var body: some View {
        Button { } label: {
            Image(systemName: "list.bullet")
        }
    }
}
