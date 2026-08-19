import Foundation

struct ColimaService: Sendable {
  private let runner: CommandRunner
  private let locator: BinaryLocator

  init(runner: CommandRunner = CommandRunner(), locator: BinaryLocator = BinaryLocator()) {
    self.runner = runner
    self.locator = locator
  }

  var colimaURL: URL? { locator.locate("colima") }
  var dockerURL: URL? { locator.locate("docker") }

  func profiles() async throws -> [ColimaProfile] {
    guard let colimaURL else { throw ServiceError.colimaNotInstalled }
    let output = try await runner.run(colimaURL, arguments: ["list", "--json"]).text
    let data = Data(output.utf8)
    let decoder = JSONDecoder()

    if let profiles = try? decoder.decode([ColimaProfile].self, from: data) {
      return profiles.sorted { $0.name < $1.name }
    }

    let profiles =
      output
      .split(whereSeparator: \.isNewline)
      .compactMap { try? decoder.decode(ColimaProfile.self, from: Data($0.utf8)) }
    return profiles.sorted { $0.name < $1.name }
  }

  func containers(profile: ColimaProfile) async throws -> [DockerContainer] {
    guard profile.runtime == "docker" else { return [] }
    guard let dockerURL else { throw ServiceError.dockerNotInstalled }
    let endpoint = dockerEndpoint(profileName: profile.name)
    let idOutput = try await runner.run(
      dockerURL,
      arguments: ["--host", endpoint, "container", "ls", "--all", "--quiet", "--no-trunc"]
    ).text
    let ids = idOutput.split(whereSeparator: \.isNewline).map(String.init)
    guard !ids.isEmpty else { return [] }

    let inspectOutput = try await runner.run(
      dockerURL,
      arguments: ["--host", endpoint, "container", "inspect"] + ids
    ).text
    return try JSONDecoder()
      .decode([DockerInspect].self, from: Data(inspectOutput.utf8))
      .map { $0.container() }
      .sorted { lhs, rhs in
        if lhs.isRunning != rhs.isRunning { return lhs.isRunning }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
  }

  func perform(_ action: ProfileAction, profileName: String) async throws {
    guard let colimaURL else { throw ServiceError.colimaNotInstalled }
    _ = try await runner.run(colimaURL, arguments: [action.rawValue, "--profile", profileName])
  }

  func perform(_ action: ContainerAction, containerIDs: [String], profileName: String) async throws
  {
    guard !containerIDs.isEmpty else { return }
    guard let dockerURL else { throw ServiceError.dockerNotInstalled }
    var arguments = [
      "--host", dockerEndpoint(profileName: profileName), "container", action.rawValue,
    ]
    if action == .remove { arguments.append("--force") }
    arguments.append(contentsOf: containerIDs)
    _ = try await runner.run(dockerURL, arguments: arguments)
  }

  func diskUsage(profileName: String) async throws -> [DockerResourceUsage] {
    guard let dockerURL else { throw ServiceError.dockerNotInstalled }
    let output = try await runner.run(
      dockerURL,
      arguments: [
        "--host", dockerEndpoint(profileName: profileName), "system", "df", "--format",
        "{{json .}}",
      ]
    ).text

    return
      output
      .split(whereSeparator: \.isNewline)
      .compactMap { try? JSONDecoder().decode(DockerResourceUsage.self, from: Data($0.utf8)) }
  }

  func prune(_ categories: Set<CleanupCategory>, profileName: String) async throws
    -> [CleanupResult]
  {
    guard let dockerURL else { throw ServiceError.dockerNotInstalled }
    let endpoint = dockerEndpoint(profileName: profileName)
    var results: [CleanupResult] = []

    for category in CleanupCategory.allCases where categories.contains(category) {
      let output = try await runner.run(
        dockerURL,
        arguments: ["--host", endpoint] + category.dockerArguments
      ).text
      results.append(CleanupResult(category: category, output: output))
    }

    return results
  }

  func dockerEndpoint(profileName: String) -> String {
    let socket = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".colima", isDirectory: true)
      .appendingPathComponent(profileName, isDirectory: true)
      .appendingPathComponent("docker.sock")
    return "unix://\(socket.path)"
  }

  enum ServiceError: LocalizedError, Sendable {
    case colimaNotInstalled
    case dockerNotInstalled

    var errorDescription: String? {
      switch self {
      case .colimaNotInstalled:
        return
          "Colima was not found. Install it with Homebrew, MacPorts, or another supported package manager."
      case .dockerNotInstalled:
        return "The Docker CLI was not found. Install it to manage containers in Docker profiles."
      }
    }
  }
}
