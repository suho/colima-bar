import Foundation

struct PublishedPort: Identifiable, Hashable, Sendable {
  let hostIP: String
  let hostPort: Int
  let containerPort: Int
  let protocolName: String

  var id: String {
    "\(hostIP):\(hostPort):\(containerPort)/\(protocolName)"
  }

  var displayName: String {
    hostPort == containerPort ? "\(hostPort)" : "\(hostPort):\(containerPort)"
  }

  var address: String {
    let host = ["", "0.0.0.0", "::", "::0"].contains(hostIP) ? "localhost" : hostIP
    return "\(host):\(hostPort)"
  }

  var webURL: URL? {
    URL(string: "http://\(address)")
  }
}

struct ContainerMount: Identifiable, Hashable, Sendable {
  let source: String
  let destination: String
  let type: String

  var id: String { "\(source):\(destination)" }
}

struct DockerContainer: Identifiable, Hashable, Sendable {
  let id: String
  let name: String
  let image: String
  let state: String
  let health: String?
  let ports: [PublishedPort]
  let mounts: [ContainerMount]
  let labels: [String: String]

  var shortID: String { String(id.prefix(12)) }

  var isRunning: Bool {
    state.caseInsensitiveCompare("running") == .orderedSame
  }

  var statusDisplayName: String {
    if let health, !health.isEmpty, health != "none" {
      return "\(state.capitalized) · \(health.capitalized)"
    }
    return state.capitalized
  }

  var composeProject: String? {
    labels["com.docker.compose.project"]
  }

  var composeService: String? {
    labels["com.docker.compose.service"]
  }
}

struct ContainerGroup: Identifiable, Sendable {
  let id: String
  let title: String
  let isComposeProject: Bool
  let containers: [DockerContainer]
}

enum ContainerAction: String, Sendable {
  case start
  case stop
  case restart
  case remove = "rm"
}
