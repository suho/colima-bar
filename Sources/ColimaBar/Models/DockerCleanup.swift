import Foundation

enum CleanupCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
  case containers
  case images
  case volumes
  case networks
  case buildCache

  var id: String { rawValue }

  var title: String {
    switch self {
    case .containers: "Stopped Containers"
    case .images: "Unused Images"
    case .volumes: "Unused Volumes"
    case .networks: "Unused Networks"
    case .buildCache: "Build Cache"
    }
  }

  var detail: String {
    switch self {
    case .containers: "Remove all stopped containers."
    case .images: "Remove images not used by a container."
    case .volumes: "Remove named and anonymous unused volumes."
    case .networks: "Remove custom networks not used by a container."
    case .buildCache: "Remove build cache that recent builds do not use."
    }
  }

  var systemImage: String {
    switch self {
    case .containers: "shippingbox"
    case .images: "square.stack.3d.up"
    case .volumes: "externaldrive"
    case .networks: "network"
    case .buildCache: "hammer"
    }
  }

  var dockerArguments: [String] {
    switch self {
    case .containers: ["container", "prune", "--force"]
    case .images: ["image", "prune", "--all", "--force"]
    case .volumes: ["volume", "prune", "--all", "--force"]
    case .networks: ["network", "prune", "--force"]
    case .buildCache: ["builder", "prune", "--force"]
    }
  }

  var diskUsageType: String? {
    switch self {
    case .containers: "Containers"
    case .images: "Images"
    case .volumes: "Local Volumes"
    case .networks: nil
    case .buildCache: "Build Cache"
    }
  }
}

struct DockerResourceUsage: Decodable, Identifiable, Hashable, Sendable {
  let type: String
  let totalCount: String
  let active: String
  let size: String
  let reclaimable: String

  var id: String { type }

  enum CodingKeys: String, CodingKey {
    case type = "Type"
    case totalCount = "TotalCount"
    case active = "Active"
    case size = "Size"
    case reclaimable = "Reclaimable"
  }

  var unusedCount: Int? {
    guard let total = Int(totalCount), let activeCount = Int(active) else { return nil }
    return max(total - activeCount, 0)
  }
}

struct CleanupResult: Sendable {
  let category: CleanupCategory
  let output: String

  /// Docker prune prints a trailing "Total reclaimed space: 1.2GB" line.
  var reclaimedSpace: String? {
    output
      .split(whereSeparator: \.isNewline)
      .last { $0.localizedCaseInsensitiveContains("Total reclaimed space") }
      .map { $0.trimmingCharacters(in: .whitespaces) }
  }
}
