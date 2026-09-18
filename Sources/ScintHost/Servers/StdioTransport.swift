import Foundation


/// Newline-delimited stdio transport for MCP messages.
///
/// Invariants:
/// - stdin is read as a sequence of complete newline-delimited JSON messages;
/// - stdout contains only newline-delimited JSON messages;
/// - EOF ends input without synthesizing a protocol message.
///
/// Non-goals: decoding JSON-RPC, dispatching MCP methods, retaining request
/// state, or interpreting Scint context.
struct StdioTransport {
    let input: FileHandle
    let output: FileHandle

    init(
        input: FileHandle = .standardInput,
        output: FileHandle = .standardOutput
    ) {
        self.input = input
        self.output = output
    }

    /// Reads the next complete message, or returns `nil` after EOF.
    func read() async throws -> Data? {
        let maximumFrameLength = 16 * 1_024 * 1_024
        var message = Data()

        while true {
            guard let byte = try input.read(upToCount: 1), !byte.isEmpty else {
                guard message.isEmpty else { throw CocoaError(.fileReadUnknown) }
                return nil
            }
            if byte[byte.startIndex] == 0x0A {
                if message.last == 0x0D { message.removeLast() }
                return message
            }
            message.append(byte)
            guard message.count <= maximumFrameLength else { throw CocoaError(.fileReadTooLarge) }
        }
    }

    /// Writes one already-encoded newline-delimited message.
    func write(_ message: Data) async throws {
        try output.write(contentsOf: message)
    }
}
