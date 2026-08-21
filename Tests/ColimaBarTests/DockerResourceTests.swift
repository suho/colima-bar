import Foundation
import Testing

@testable import ColimaBar

struct DockerResourceTests {
  @Test
  func listsEachResourceKindAsJSONLines() {
    #expect(ResourceKind.containers.listArguments == nil)
    #expect(
      ResourceKind.images.listArguments == ["image", "ls", "--all", "--format", "{{json .}}"])
    #expect(ResourceKind.volumes.listArguments == ["volume", "ls", "--format", "{{json .}}"])
    #expect(ResourceKind.networks.listArguments == ["network", "ls", "--format", "{{json .}}"])
    #expect(ResourceKind.buildCache.listArguments == ["buildx", "du", "--format", "{{json .}}"])
  }

  @Test
  func buildsRemoveAllArguments() {
    #expect(
      ResourceKind.containers.removeAllArguments(references: ["a", "b"])
        == ["container", "rm", "--force", "--volumes", "a", "b"])
    #expect(
      ResourceKind.images.removeAllArguments(references: ["nginx:latest"])
        == ["image", "rm", "--force", "nginx:latest"])
    #expect(
      ResourceKind.volumes.removeAllArguments(references: ["data"])
        == ["volume", "rm", "--force", "data"])
    #expect(
      ResourceKind.networks.removeAllArguments(references: ["web"]) == ["network", "rm", "web"])
    #expect(
      ResourceKind.buildCache.removeAllArguments(references: [])
        == ["builder", "prune", "--all", "--force"])
  }

  @Test
  func prunesBuildCacheAsAWholeInsteadOfByReference() {
    #expect(ResourceKind.buildCache.removesByReference == false)
    #expect(ResourceKind.containers.removesByReference)
    #expect(CleanupCategory.buildCache.dockerArguments == ["builder", "prune", "--force"])
    #expect(CleanupCategory.buildCache.diskUsageType == "Build Cache")
  }

  @Test
  func decodesBuildCacheRecord() throws {
    let line = """
      {"CreatedAt":"2026-08-19 13:13:31 +0000 UTC","Description":"[4/9] WORKDIR /app",\
      "ID":"5e9kozi9rnzaqnplmhgpsjbh5","LastUsedAt":"2 days ago","Mutable":false,\
      "Parents":["tywot0cl6xqitg3qwn5kfo3ro"],"Reclaimable":true,"Shared":true,\
      "Size":"4.128kB","Type":"regular","UsageCount":1}
      """
    let record = try JSONDecoder().decode(DockerBuildCacheRecord.self, from: Data(line.utf8))

    #expect(record.id == "5e9kozi9rnzaqnplmhgpsjbh5")
    #expect(record.displayName == "[4/9] WORKDIR /app")
    #expect(record.size == "4.128kB")
    #expect(record.isReclaimable)
    #expect(record.isShared)
  }

  @Test
  func fallsBackToTheCacheIDWhenThereIsNoDescription() throws {
    let line = """
      {"ID":"abc123","Reclaimable":false,"Shared":false,"Size":"1B","Type":"regular"}
      """
    let record = try JSONDecoder().decode(DockerBuildCacheRecord.self, from: Data(line.utf8))

    #expect(record.displayName == "abc123")
    #expect(record.isReclaimable == false)
  }

  @Test
  func decodesImageListLine() throws {
    let line = """
      {"Containers":"N/A","CreatedSince":"3 weeks ago","ID":"sha256:1a2b3c4d5e6f7a8b","\
      Repository":"nginx","Size":"192MB","Tag":"latest"}
      """
    let image = try JSONDecoder().decode(DockerImage.self, from: Data(line.utf8))

    #expect(image.displayName == "nginx:latest")
    #expect(image.shortID == "1a2b3c4d5e6f")
    #expect(image.isUntagged == false)
    #expect(image.removalReference == "nginx:latest")
    #expect(image.usedByContainerCount == nil)
  }

  @Test
  func removesUntaggedImagesByID() throws {
    let line = """
      {"ID":"sha256:99887766554433","Repository":"<none>","Size":"12MB","Tag":"<none>"}
      """
    let image = try JSONDecoder().decode(DockerImage.self, from: Data(line.utf8))

    #expect(image.isUntagged)
    #expect(image.displayName == "998877665544")
    #expect(image.removalReference == "sha256:99887766554433")
  }

  @Test
  func decodesVolumeListLineAndIgnoresUnknownValues() throws {
    let line = """
      {"Driver":"local","Labels":"","Links":"N/A","Mountpoint":"/var/lib/docker/volumes/db/_data",\
      "Name":"db","Scope":"local","Size":"N/A"}
      """
    let volume = try JSONDecoder().decode(DockerVolume.self, from: Data(line.utf8))

    #expect(volume.name == "db")
    #expect(volume.sizeDisplayName == nil)
    #expect(volume.linkCount == nil)
  }

  @Test
  func flagsPredefinedNetworks() throws {
    let line = """
      {"Driver":"bridge","ID":"abcdef012345678","Name":"bridge","Scope":"local"}
      """
    let network = try JSONDecoder().decode(DockerNetwork.self, from: Data(line.utf8))

    #expect(network.isPredefined)
    #expect(network.shortID == "abcdef012345")
  }

  @Test
  func namesItemsBySingularAndPlural() {
    #expect(ResourceKind.images.itemNoun(1) == "image")
    #expect(ResourceKind.images.itemNoun(3) == "images")
    #expect(ResourceKind.containers.itemNoun(0) == "containers")
    #expect(ResourceKind.buildCache.itemNoun(1) == "cache record")
    #expect(ResourceKind.buildCache.itemNoun(9) == "cache records")
  }

  @Test
  func readsReclaimedSpaceFromPruneOutput() {
    let result = CleanupResult(
      category: .images,
      output: "Deleted Images:\nuntagged: nginx:latest\n\nTotal reclaimed space: 192MB\n"
    )

    #expect(result.reclaimedSpace == "Total reclaimed space: 192MB")
    #expect(CleanupResult(category: .networks, output: "").reclaimedSpace == nil)
  }
}

struct DockerVolumeMountTests {
  @Test
  func readsVolumeNameFromMount() throws {
    let json = """
      [{
        "Id": "abc123",
        "Name": "/api",
        "Config": {"Image": "postgres:16", "Labels": {}},
        "State": {"Status": "running"},
        "Mounts": [{
          "Type": "volume",
          "Name": "api_data",
          "Source": "/var/lib/docker/volumes/api_data/_data",
          "Destination": "/var/lib/postgresql/data"
        }],
        "NetworkSettings": {"Ports": {}}
      }]
      """
    let container = try JSONDecoder()
      .decode([DockerInspect].self, from: Data(json.utf8))[0]
      .container()

    #expect(container.mounts.first?.volumeName == "api_data")
  }
}
