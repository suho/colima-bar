import Testing

@testable import ColimaBar

struct DockerCleanupTests {
  @Test
  func usesDockerPruneCommands() {
    #expect(CleanupCategory.containers.dockerArguments == ["container", "prune", "--force"])
    #expect(CleanupCategory.images.dockerArguments == ["image", "prune", "--all", "--force"])
    #expect(CleanupCategory.volumes.dockerArguments == ["volume", "prune", "--all", "--force"])
    #expect(CleanupCategory.networks.dockerArguments == ["network", "prune", "--force"])
  }

  @Test
  func calculatesUnusedResourceCount() {
    let usage = DockerResourceUsage(
      type: "Images",
      totalCount: "8",
      active: "3",
      size: "2GB",
      reclaimable: "500MB (25%)"
    )

    #expect(usage.unusedCount == 5)
  }
}
