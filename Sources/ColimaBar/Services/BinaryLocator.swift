import Foundation

struct BinaryLocator: Sendable {
  func locate(_ name: String) -> URL? {
    var candidates = [
      "/opt/homebrew/bin/\(name)",
      "/usr/local/bin/\(name)",
      "/opt/local/bin/\(name)",
      "/usr/bin/\(name)",
    ]

    let pathDirectories =
      ProcessInfo.processInfo.environment["PATH"]?
      .split(separator: ":")
      .map(String.init) ?? []
    candidates.append(contentsOf: pathDirectories.map { "\($0)/\(name)" })

    return
      candidates
      .map(URL.init(fileURLWithPath:))
      .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
  }
}
