import Foundation

struct ColimaProfile: Codable, Identifiable, Hashable, Sendable {
  let name: String
  let status: String
  let arch: String
  let cpus: Int
  let memory: Int64
  let disk: Int64
  let runtime: String

  var id: String { name }

  var isRunning: Bool {
    status.caseInsensitiveCompare("running") == .orderedSame
  }

  var statusDisplayName: String {
    status.isEmpty ? "Unknown" : status.capitalized
  }

  var memoryDisplayName: String {
    ByteCountFormatter.string(fromByteCount: memory, countStyle: .memory)
  }

  var diskDisplayName: String {
    ByteCountFormatter.string(fromByteCount: disk, countStyle: .file)
  }
}

enum ProfileAction: String, Sendable {
  case start
  case stop
  case restart
}
