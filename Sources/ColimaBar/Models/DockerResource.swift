import Foundation

enum ResourceKind: String, CaseIterable, Identifiable, Hashable, Sendable {
  case containers
  case images
  case volumes
  case networks
  case buildCache

  var id: String { rawValue }

  var title: String {
    switch self {
    case .containers: "Containers"
    case .images: "Images"
    case .volumes: "Volumes"
    case .networks: "Networks"
    case .buildCache: "Build Cache"
    }
  }

  /// Fits five segments into the popover width.
  var shortTitle: String {
    self == .buildCache ? "Cache" : title
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

  var emptyDescription: String {
    switch self {
    case .containers: "Containers for this profile appear here."
    case .images: "Pulled and built images appear here."
    case .volumes: "Named and anonymous volumes appear here."
    case .networks: "Docker networks appear here."
    case .buildCache: "Layers cached by BuildKit appear here."
    }
  }

  var cleanupCategory: CleanupCategory {
    switch self {
    case .containers: .containers
    case .images: .images
    case .volumes: .volumes
    case .networks: .networks
    case .buildCache: .buildCache
    }
  }

  /// Arguments that list every resource of this kind as one JSON object per line.
  /// Containers are loaded through `container inspect` instead, so they have no list arguments.
  var listArguments: [String]? {
    switch self {
    case .containers: nil
    case .images: ["image", "ls", "--all", "--format", "{{json .}}"]
    case .volumes: ["volume", "ls", "--format", "{{json .}}"]
    case .networks: ["network", "ls", "--format", "{{json .}}"]
    case .buildCache: ["buildx", "du", "--format", "{{json .}}"]
    }
  }

  /// Build cache records are pruned as a whole; every other kind is removed by reference.
  var removesByReference: Bool { self != .buildCache }

  func removeAllArguments(references: [String]) -> [String] {
    switch self {
    case .containers: ["container", "rm", "--force", "--volumes"] + references
    case .images: ["image", "rm", "--force"] + references
    case .volumes: ["volume", "rm", "--force"] + references
    case .networks: ["network", "rm"] + references
    case .buildCache: ["builder", "prune", "--all", "--force"]
    }
  }

  var removeAllTitle: String {
    switch self {
    case .containers: "Remove All Containers"
    case .images: "Remove All Images"
    case .volumes: "Remove All Volumes"
    case .networks: "Remove All Networks"
    case .buildCache: "Remove All Build Cache"
    }
  }

  var removeAllDetail: String {
    switch self {
    case .containers:
      "Running containers are stopped and removed, together with their anonymous volumes."
    case .images: "Images still used by a container are kept and reported as an error."
    case .volumes: "All volume data is deleted. Volumes attached to a container are kept."
    case .networks: "The predefined bridge, host, and none networks are kept."
    case .buildCache: "Every cached layer is deleted, so the next build starts from scratch."
    }
  }

  var pruneDetail: String {
    switch self {
    case .containers: "Remove all stopped containers."
    case .images: "Remove images not used by a container."
    case .volumes: "Remove named and anonymous unused volumes."
    case .networks: "Remove custom networks not used by a container."
    case .buildCache: "Remove build cache that recent builds do not use."
    }
  }

  func itemNoun(_ count: Int) -> String {
    switch self {
    case .containers: count == 1 ? "container" : "containers"
    case .images: count == 1 ? "image" : "images"
    case .volumes: count == 1 ? "volume" : "volumes"
    case .networks: count == 1 ? "network" : "networks"
    case .buildCache: count == 1 ? "cache record" : "cache records"
    }
  }
}

struct DockerImage: Decodable, Identifiable, Hashable, Sendable {
  let imageID: String
  let repository: String
  let tag: String
  let size: String?
  let createdSince: String?
  let containers: String?

  enum CodingKeys: String, CodingKey {
    case imageID = "ID"
    case repository = "Repository"
    case tag = "Tag"
    case size = "Size"
    case createdSince = "CreatedSince"
    case containers = "Containers"
  }

  /// The same image ID can appear once per tag, so the identity has to include the tag.
  var id: String { "\(repository):\(tag)@\(imageID)" }

  var shortID: String {
    let digest = imageID.hasPrefix("sha256:") ? String(imageID.dropFirst(7)) : imageID
    return String(digest.prefix(12))
  }

  var isUntagged: Bool { repository == "<none>" || tag == "<none>" }

  var displayName: String {
    if repository == "<none>" { return shortID }
    if tag == "<none>" { return repository }
    return "\(repository):\(tag)"
  }

  /// Removing a tagged image by reference drops only that tag; untagged layers go by ID.
  var removalReference: String { isUntagged ? imageID : displayName }

  var usedByContainerCount: Int? {
    guard let containers, let count = Int(containers), count >= 0 else { return nil }
    return count
  }
}

struct DockerVolume: Decodable, Identifiable, Hashable, Sendable {
  let name: String
  let driver: String?
  let mountpoint: String?
  let size: String?
  let links: String?

  enum CodingKeys: String, CodingKey {
    case name = "Name"
    case driver = "Driver"
    case mountpoint = "Mountpoint"
    case size = "Size"
    case links = "Links"
  }

  var id: String { name }

  var sizeDisplayName: String? { Self.knownValue(size) }

  var linkCount: Int? {
    guard let value = Self.knownValue(links) else { return nil }
    return Int(value)
  }

  private static func knownValue(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, trimmed != "N/A", trimmed != "<none>" else { return nil }
    return trimmed
  }
}

struct DockerNetwork: Decodable, Identifiable, Hashable, Sendable {
  static let predefinedNames = ["bridge", "host", "none"]

  let networkID: String
  let name: String
  let driver: String?
  let scope: String?

  enum CodingKeys: String, CodingKey {
    case networkID = "ID"
    case name = "Name"
    case driver = "Driver"
    case scope = "Scope"
  }

  var id: String { networkID }

  var shortID: String { String(networkID.prefix(12)) }

  var isPredefined: Bool { Self.predefinedNames.contains(name) }
}

struct DockerBuildCacheRecord: Decodable, Identifiable, Hashable, Sendable {
  let id: String
  let type: String?
  let size: String?
  let description: String?
  let lastUsedAt: String?
  let usageCount: Int?
  let reclaimable: Bool?
  let shared: Bool?

  enum CodingKeys: String, CodingKey {
    case id = "ID"
    case type = "Type"
    case size = "Size"
    case description = "Description"
    case lastUsedAt = "LastUsedAt"
    case usageCount = "UsageCount"
    case reclaimable = "Reclaimable"
    case shared = "Shared"
  }

  var isReclaimable: Bool { reclaimable ?? true }

  var isShared: Bool { shared ?? false }

  var displayName: String {
    guard let description, !description.isEmpty else { return id }
    return description
  }
}
