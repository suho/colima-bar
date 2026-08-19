import AppKit
import Foundation

@MainActor
struct DesktopIntegration {
  private let locator = BinaryLocator()

  func open(_ port: PublishedPort) {
    guard let url = port.webURL else { return }
    NSWorkspace.shared.open(url)
  }

  func openMount(_ mount: ContainerMount) throws {
    let url = URL(fileURLWithPath: mount.source)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw IntegrationError.mountNotAvailable(mount.source)
    }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func copy(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
  }

  func openContainerShell(container: DockerContainer, endpoint: String) throws {
    guard let dockerURL = locator.locate("docker") else {
      throw IntegrationError.binaryNotFound("docker")
    }
    let command = [
      shellQuote(dockerURL.path), "--host", shellQuote(endpoint),
      "container", "exec", "-it", shellQuote(container.id), "/bin/sh",
    ].joined(separator: " ")
    try openGhostty(command: command, title: "Shell · \(container.name)")
  }

  func openContainerLogs(container: DockerContainer, endpoint: String) throws {
    guard let dockerURL = locator.locate("docker") else {
      throw IntegrationError.binaryNotFound("docker")
    }
    let command = [
      shellQuote(dockerURL.path), "--host", shellQuote(endpoint),
      "container", "logs", "--follow", "--tail", "200", shellQuote(container.id),
    ].joined(separator: " ")
    try openGhostty(command: command, title: "Logs · \(container.name)")
  }

  func openColimaShell(profileName: String) throws {
    guard let colimaURL = locator.locate("colima") else {
      throw IntegrationError.binaryNotFound("colima")
    }
    let command = [shellQuote(colimaURL.path), "ssh", "--profile", shellQuote(profileName)].joined(
      separator: " ")
    try openGhostty(command: command, title: "Colima · \(profileName)")
  }

  private func openGhostty(command: String, title: String) throws {
    guard let ghosttyURL = ghosttyApplicationURL() else {
      throw IntegrationError.ghosttyNotFound
    }

    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [
      "-n", "-a", ghosttyURL.path, "--args", "--title=\(title)", "-e", "/bin/zsh", "-lc",
      "\(command); exec /bin/zsh -l",
    ]
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let detail = String(decoding: data, as: UTF8.self).trimmingCharacters(
        in: .whitespacesAndNewlines)
      throw IntegrationError.ghosttyLaunchFailed(
        detail.isEmpty ? "Ghostty could not open the command." : detail)
    }
  }

  private func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  private func ghosttyApplicationURL() -> URL? {
    if let installedURL = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: "com.mitchellh.ghostty")
    {
      return installedURL
    }

    return [
      URL(fileURLWithPath: "/Applications/Ghostty.app"),
      FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications", isDirectory: true)
        .appendingPathComponent("Ghostty.app", isDirectory: true),
    ].first { FileManager.default.fileExists(atPath: $0.path) }
  }

  enum IntegrationError: LocalizedError {
    case binaryNotFound(String)
    case mountNotAvailable(String)
    case ghosttyNotFound
    case ghosttyLaunchFailed(String)

    var errorDescription: String? {
      switch self {
      case .binaryNotFound(let name):
        return "The \(name) command was not found."
      case .mountNotAvailable(let path):
        return "The mount is not available on this Mac: \(path)"
      case .ghosttyNotFound:
        return "Ghostty was not found in Applications."
      case .ghosttyLaunchFailed(let detail):
        return detail
      }
    }
  }
}
