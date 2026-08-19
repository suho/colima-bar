import Foundation

struct DockerInspect: Decodable, Sendable {
  let id: String
  let rawName: String
  let config: Config
  let state: State
  let mounts: [Mount]
  let networkSettings: NetworkSettings

  enum CodingKeys: String, CodingKey {
    case id = "Id"
    case rawName = "Name"
    case config = "Config"
    case state = "State"
    case mounts = "Mounts"
    case networkSettings = "NetworkSettings"
  }

  struct Config: Decodable, Sendable {
    let image: String
    let labels: [String: String]?

    enum CodingKeys: String, CodingKey {
      case image = "Image"
      case labels = "Labels"
    }
  }

  struct State: Decodable, Sendable {
    let status: String
    let health: Health?

    enum CodingKeys: String, CodingKey {
      case status = "Status"
      case health = "Health"
    }
  }

  struct Health: Decodable, Sendable {
    let status: String

    enum CodingKeys: String, CodingKey {
      case status = "Status"
    }
  }

  struct Mount: Decodable, Sendable {
    let type: String
    let source: String
    let destination: String

    enum CodingKeys: String, CodingKey {
      case type = "Type"
      case source = "Source"
      case destination = "Destination"
    }
  }

  struct NetworkSettings: Decodable, Sendable {
    let ports: [String: [PortBinding]?]?

    enum CodingKeys: String, CodingKey {
      case ports = "Ports"
    }
  }

  struct PortBinding: Decodable, Sendable {
    let hostIP: String
    let hostPort: String

    enum CodingKeys: String, CodingKey {
      case hostIP = "HostIp"
      case hostPort = "HostPort"
    }
  }

  func container() -> DockerContainer {
    DockerContainer(
      id: id,
      name: rawName.hasPrefix("/") ? String(rawName.dropFirst()) : rawName,
      image: config.image,
      state: state.status,
      health: state.health?.status,
      ports: publishedPorts,
      mounts: mounts.map {
        ContainerMount(source: $0.source, destination: $0.destination, type: $0.type)
      },
      labels: config.labels ?? [:]
    )
  }

  private var publishedPorts: [PublishedPort] {
    guard let ports = networkSettings.ports else { return [] }
    var result: [PublishedPort] = []

    for (containerAddress, bindings) in ports {
      let parts = containerAddress.split(separator: "/", maxSplits: 1).map(String.init)
      guard let containerPort = Int(parts.first ?? "") else { continue }
      let protocolName = parts.count > 1 ? parts[1] : "tcp"

      for binding in bindings ?? [] {
        guard let hostPort = Int(binding.hostPort) else { continue }
        let port = PublishedPort(
          hostIP: binding.hostIP,
          hostPort: hostPort,
          containerPort: containerPort,
          protocolName: protocolName
        )
        if !result.contains(where: {
          $0.hostPort == port.hostPort && $0.containerPort == port.containerPort
        }) {
          result.append(port)
        }
      }
    }

    return result.sorted { $0.hostPort < $1.hostPort }
  }
}
