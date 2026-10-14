import Foundation
import SwiftUI
@testable import ScintRuntime
@testable import Scint


@MainActor final class Probe: Model {
    var session: Session {
        get { preconditionFailure("panel wiring prepared content that reads the session") }
        set {}
    }
}

@MainActor var failures = 0
@MainActor func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { failures += 1 }
    print(condition ? "PASS" : "FAIL", "[\(line)]", message)
}

@main struct PanelRegression {
    @MainActor static func main() {
        let probe = Probe()
        let state = StateContainer()
        let rows = ["One", "Two", "Three"].map { ItemParams(key: "row", name: $0, value: $0) }
        var evaluated = 0
        var picked: [String] = []
        func handle(_ input: Controls.Input, _ supplied: [ItemParams]? = nil, secondary: ((ItemParams) -> Void)? = nil, cancel: (() -> Bool)? = nil) -> Bool {
            PanelNavigation.handle(input, rows: { evaluated += 1; return supplied ?? rows }, index: state.bindable.index,
                                   onSelect: { picked.append($0.name) }, onSecondary: secondary, onCancel: cancel)
        }

        check(handle(.move(-1)) && state.index == 2, "up from the first row wraps to the last")
        check(handle(.move(1)) && state.index == 0, "down from the last row wraps to the first")
        check(evaluated == 2, "each move evaluates rows exactly once")
        evaluated = 0
        check(!handle(.cancel) && evaluated == 0, "unhandled cancel falls through without evaluating rows")
        check(handle(.cancel, cancel: { true }) && evaluated == 0, "a supplied cancel consumes without evaluating rows")
        state.index = 1
        check(handle(.submit) && picked == ["Two"], "submit selects the current row once")
        check(handle(.secondary) && state.index == 2, "secondary without a callback moves forward")
        var forwarded: [String] = []
        check(handle(.secondary, secondary: { forwarded.append($0.name) }) && forwarded == ["Three"] && state.index == 2, "a supplied secondary receives the current row and leaves the cursor")
        state.index = 7
        picked = []
        check(handle(.submit, [rows[0]]) && picked == ["One"], "a shrunken result list clamps the cursor to its last row")
        check(PanelNavigation.current(rows, at: 7)?.name == "Three" && PanelNavigation.current([], at: 0) == nil, "current clamps past the end and is nil for no rows")
        picked = []
        state.index = 1
        check(handle(.move(1), []) && handle(.submit, []) && handle(.secondary, [], secondary: { _ in picked.append("secondary") }) && picked.isEmpty && state.index == 1,
              "empty results consume movement and activation without effects")

        let tabbed = Params(tabbed: true, sections: [
            SectionParams(id: "a", name: "A", sections: [SectionParams(id: "a1", items: [ItemParams(name: "Hidden")])]),
            SectionParams(id: "b", name: "B", sections: [SectionParams(id: "b1", items: [
                ItemParams(name: "Parent", items: [ItemParams(name: "Child"), ItemParams(name: "Note", trailingKind: .field)]),
                ItemParams(name: "Kind", actionable: false),
                ItemParams(name: "Visible")
            ])])
        ])
        check(tabbed.rows("b").map(\.name) == ["Child", "Visible"], "rows come from the selected tab only, expose parent children, and skip metadata and fields")
        check(tabbed.rows("missing").map(\.name) == ["Hidden"], "an unknown tab falls back to the first tab, as rendering does")
        check(tabbed.shown("b").map(\.id) == [AnyHashable("b1")], "shown sections are the selected tab's content")

        let choices = ChoiceMenu()
        var chosen: [String] = []
        choices.items = ["Alpha", "Beta", "Gamma"].map { ItemParams(key: "choice", name: $0, value: $0, active: $0 == "Beta") }
        choices.onPick = { chosen.append($0.name) }
        let choiceControls = choices.controls(probe)
        let choiceParams = choices.parameters(probe)
        check(choiceParams.cursor == choices.items[0].id && choiceParams.input?.value == "", "the choice cursor starts on the first visible choice")
        check(choiceControls.selected?(choices.items[1]) == true && choiceControls.selected?(choices.items[0]) == false, "checked selection stays independent of the cursor")
        check(choiceControls.onInput?(.move(1)) == true && choices.parameters(probe).cursor == choices.items[1].id, "arrow movement and the rendered cursor agree")
        choiceControls.onValueChange?(choiceParams.input!, "")
        check(choices.state.index == 1, "re-sending the unchanged query keeps the cursor")
        choiceControls.onValueChange?(choiceParams.input!, "ga")
        check(choices.state.query == "ga" && choices.state.index == 0, "a header query edit updates the query and resets the cursor")
        choiceControls.onValueChange?(ItemParams(key: "note", name: "Note", trailingKind: .field), "typed")
        check(choices.state.query == "ga", "an ordinary field does not edit the query")
        let filtered = choices.parameters(probe)
        check(filtered.rows(choices.state.surface).map(\.name) == ["Gamma"] && filtered.cursor == choices.items[2].id, "filtering narrows rows and the cursor follows")
        check(choiceControls.onInput?(.submit) == true && chosen == ["Gamma"], "Return picks the current choice once")
        choiceControls.onSelect?(choices.items[2])
        check(chosen == ["Gamma", "Gamma"], "a click reaches the same pick callback once")
        check(choiceControls.onInput?(.cancel) == false, "choice cancellation falls through to the panel's dismissal")
        check(choiceControls.onInput?(.secondary) == true && !choices.state.detail, "Tab in a choice menu never enters detail")

        let menu = EditorMenu()
        let commands = menu.parameters(probe)
        let commandRows = commands.rows(menu.state.surface)
        check(commandRows.count == 11 && commands.shown(menu.state.surface).count == 3 && commands.cursor == commandRows.first?.id, "commands render as three sections with the first command under the cursor")
        check(menu.controls(probe).onInput?(.move(-1)) == true && menu.parameters(probe).cursor == commandRows.last?.id, "moving up from the first command wraps to the last")
        check(menu.controls(probe).onInput?(.cancel) == false, "editor cancellation falls through to closeMenu")
        menu.surface = .task
        menu.state.index = 0
        let form = menu.parameters(probe)
        menu.controls(probe).onValueChange?(form.input!, "Buy milk")
        check(form.rows(menu.state.surface).map(\.name) == ["Insert Task"] && menu.state.query == "Buy milk", "the task form edits its owned value and exposes one commit row")

        let search = SearchPanel()
        let results = search.controls(probe)
        check(results.onInput?(.cancel) == false && search.surface == .results, "Escape in search results falls through to dismissal")
        search.state.query = "draft"
        search.state.index = 3
        results.onTabSelect?(SectionParams(id: "content", name: "Content"))
        check(search.state.surface == "content" && search.state.query == "" && search.state.index == 0, "a tab switch resets query and cursor")
        results.onValueChange?(ItemParams(key: "note", name: "Note", trailingKind: .field), "typed")
        check(search.state.query == "", "an ordinary field does not edit the search query")
        search.surface = .detail
        search.state.index = 2
        let detail = search.controls(probe)
        check(detail.onInput?(.cancel) == true && search.surface == .results && search.state.index == 0, "Escape in detail returns to results without preparing content")

        let declared = SearchList.parameters(probe)
        let hierarchy: [[AnyHashable]] = [["document", "interface", "structure"], ["document"], ["artifact", "command", "harness"], ["structure"]]
        check(declared.sections.map(\.name) == ["Everything", "Content", "Interfaces", "Projects"]
              && declared.sections.map(\.image) == ["magnifyingglass", "command", "switch.2", "cube.transparent"],
              "SearchList.parameters declares the tabs with their labels and icons")
        check(declared.sections.map { $0.sections.map(\.id) } == hierarchy
              && declared.sections[0].sections.map(\.name) == ["Content", "Interfaces", "Workspace"]
              && declared.sections[2].sections.map(\.name) == ["Artifacts", "Commands", "Harnesses"]
              && declared.sections.flatMap(\.sections).allSatisfy { $0.items.isEmpty && $0.layout == .list },
              "every tab declares its child sections before any query runs")

        let space = Space.new(from: .init(name: "Seedling Space"))
        _ = ScintRuntime.Document.new(from: .init(name: "Seedling Notes", origin: space))
        let artifact = Artifact.new("Seedling Artifact", URL(fileURLWithPath: "/tmp/seedling"))
        _ = Command.new(name: "Seedling Command", description: "", artifact: artifact)

        let declaredChild = declared.sections[0].sections[0]
        let returned = SearchList.controls(probe).results?(declaredChild, "Seedling") ?? []
        print("TRACE declared \(declaredChild.id) \"\(declaredChild.name)\" header=\(declaredChild.header) items=\(declaredChild.items.map(\.name))",
              "-> returned", returned.map { "\($0.id) \"\($0.name)\" header=\($0.header) items=\($0.items.map(\.name))" })
        check(returned.count == 1 && returned[0].id == declaredChild.id && returned[0].name == "Content" && returned[0].header && returned[0].layout == .list
              && returned[0].items.map(\.name).contains("Seedling Notes"),
              "the query callback returns the declared section with its metadata and its items filled")
        let renamed = ReferenceList.controls(probe).results?(SectionParams(id: "document", name: "Notes", layout: .list), "Seedling") ?? []
        check(renamed.first?.name == "Notes" && renamed.first?.items.map(\.name) == returned.first?.items.map(\.name),
              "a label change leaves the category filter untouched")

        let finder = SearchPanel()
        finder.state.query = "Seedling"
        func shown(_ tab: String) -> (params: Params, groups: [AnyHashable], names: [String]) {
            finder.state.surface = tab
            let params = finder.parameters(probe)
            return (params, params.shown(tab).map(\.id), params.shown(tab).map(\.name))
        }
        let everything = shown("everything")
        check(everything.groups == ["document", "interface", "structure"] && everything.names == ["Content", "Interfaces", "Workspace"]
              && everything.params.shown("everything").map { $0.items.map(\.name) } == [["Seedling Notes"], ["Seedling Command"], ["Seedling Space"]],
              "Everything resolves its three declared groups in order")
        check(everything.params.sections.filter { $0.id != AnyHashable("everything") }.flatMap(\.sections).allSatisfy(\.items.isEmpty),
              "inactive tabs keep their declarations unpopulated")
        check(everything.params.cursor == everything.params.rows("everything").first?.id && everything.params.input?.name == "Everything",
              "the cursor and header input follow the selected tab")
        let content = shown("content")
        check(content.groups == ["document"] && content.names == [""], "Content resolves its one unlabeled group")
        let interfaces = shown("interfaces")
        check(interfaces.groups == ["artifact", "command"] && interfaces.names == ["Artifacts", "Commands"], "Interfaces hides its empty Harnesses group")
        let projects = shown("projects")
        check(projects.groups == ["structure"] && projects.params.rows("projects").map(\.name).contains("Seedling Space"), "Projects resolves its one group")

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        exit(failures == 0 ? 0 : 1)
    }
}
