import Foundation

@main
enum agency {
    static func main() async {
        let registry = CommandRegistry(addons: [
            CoreCommandsAddon(),
            StaticCommandsAddon(),
            RemindersAddon()
        ])

        let runner = CommandRunner(registry: registry)

        do {
            let output = try await runner.run(arguments: Array(CommandLine.arguments.dropFirst()))
            if !output.isEmpty {
                print(output)
            }
        } catch let error as CommandError {
            fputs("\(error.rendered)\n", stderr)
            Foundation.exit(EXIT_FAILURE)
        } catch {
            fputs("Something went sideways: \(error.localizedDescription)\n", stderr)
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
