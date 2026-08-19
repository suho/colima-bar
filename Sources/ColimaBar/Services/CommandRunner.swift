import Foundation

struct CommandOutput: Sendable {
  let text: String
  let exitCode: Int32
}

struct CommandFailure: LocalizedError, Sendable {
  let executable: String
  let output: String
  let exitCode: Int32

  var errorDescription: String? {
    let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
    if detail.isEmpty {
      return "\(executable) exited with status \(exitCode)."
    }
    return detail
  }
}

final class CommandRunner: @unchecked Sendable {
  func run(
    _ executable: URL,
    arguments: [String],
    environment additions: [String: String] = [:]
  ) async throws -> CommandOutput {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = Self.commandPath
        for (key, value) in additions {
          environment[key] = value
        }
        process.environment = environment

        do {
          try process.run()
          let data = pipe.fileHandleForReading.readDataToEndOfFile()
          process.waitUntilExit()
          let output = String(decoding: data, as: UTF8.self)
          guard process.terminationStatus == 0 else {
            throw CommandFailure(
              executable: executable.lastPathComponent,
              output: output,
              exitCode: process.terminationStatus
            )
          }
          continuation.resume(
            returning: CommandOutput(text: output, exitCode: process.terminationStatus))
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  static let commandPath =
    "/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
}
