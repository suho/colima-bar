import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
  enum Page {
    case dashboard
    case settings
    case cleanup
  }

  private let service: ColimaService
  private let launchAtLoginService: LaunchAtLoginService
  private let desktopIntegration: DesktopIntegration
  private let defaults: UserDefaults

  var profiles: [ColimaProfile] = []
  var selectedProfileName = "default"
  var containers: [DockerContainer] = []
  private var isRefreshInFlight = false
  var isShowingRefreshIndicator = false
  var activeOperation: String?
  var errorMessage: String?
  var launchAtLoginEnabled = false
  var launchAtLoginError: String?
  var page: Page = .dashboard
  var cleanupSelection: Set<CleanupCategory> = []
  var diskUsage: [DockerResourceUsage] = []
  var isLoadingDiskUsage = false
  var cleanupResultMessage: String?

  var autoStartColima: Bool {
    get { defaults.object(forKey: Keys.autoStartColima) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Keys.autoStartColima) }
  }

  var selectedProfile: ColimaProfile? {
    profiles.first { $0.name == selectedProfileName }
  }

  var runningContainerCount: Int {
    containers.count(where: \.isRunning)
  }

  var groups: [ContainerGroup] {
    let grouped = Dictionary(grouping: containers) { container in
      container.composeProject ?? ""
    }
    return grouped.map { key, value in
      ContainerGroup(
        id: key.isEmpty ? "standalone" : "compose:\(key)",
        title: key.isEmpty ? "Standalone" : key,
        isComposeProject: !key.isEmpty,
        containers: value.sorted {
          $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
      )
    }
    .sorted { lhs, rhs in
      if lhs.isComposeProject != rhs.isComposeProject { return lhs.isComposeProject }
      return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
  }

  var statusSymbol: String {
    if activeOperation != nil || isShowingRefreshIndicator {
      return "shippingbox.and.arrow.backward.fill"
    }
    if selectedProfile?.isRunning == true { return "shippingbox.fill" }
    return "shippingbox"
  }

  init(
    service: ColimaService = ColimaService(),
    launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService(),
    desktopIntegration: DesktopIntegration = DesktopIntegration(),
    defaults: UserDefaults = .standard
  ) {
    self.service = service
    self.launchAtLoginService = launchAtLoginService
    self.desktopIntegration = desktopIntegration
    self.defaults = defaults
    launchAtLoginEnabled = launchAtLoginService.isEnabled

    Task { await bootstrap() }
  }

  func bootstrap() async {
    if defaults.object(forKey: Keys.launchAtLoginRequested) == nil {
      defaults.set(true, forKey: Keys.launchAtLoginRequested)
    }
    if defaults.bool(forKey: Keys.launchAtLoginRequested), !launchAtLoginEnabled {
      setLaunchAtLogin(true)
    }

    await refresh()
    guard autoStartColima else { return }

    if profiles.isEmpty {
      await perform(.start, profileName: "default")
    } else if selectedProfile?.isRunning == false {
      await perform(.start, profileName: selectedProfileName)
    }
  }

  func refresh(silent: Bool = false) async {
    await executeRefresh(silent: silent, showsIndicator: false)
  }

  func refreshFromUser() async {
    guard activeOperation == nil else { return }

    while isRefreshInFlight {
      try? await Task.sleep(for: .milliseconds(25))
      guard activeOperation == nil else { return }
    }

    await executeRefresh(silent: false, showsIndicator: true)
  }

  private func executeRefresh(silent: Bool, showsIndicator: Bool) async {
    guard !isRefreshInFlight, activeOperation == nil else { return }
    isRefreshInFlight = true
    isShowingRefreshIndicator = showsIndicator
    defer {
      isRefreshInFlight = false
      isShowingRefreshIndicator = false
    }

    do {
      let loadedProfiles = try await service.profiles()
      profiles = loadedProfiles
      if !loadedProfiles.contains(where: { $0.name == selectedProfileName }) {
        selectedProfileName =
          loadedProfiles.first(where: \.isRunning)?.name ?? loadedProfiles.first?.name ?? "default"
      }

      if let profile = selectedProfile, profile.isRunning {
        containers = try await service.containers(profile: profile)
      } else {
        containers = []
      }
      errorMessage = nil
    } catch {
      if !silent || profiles.isEmpty {
        errorMessage = error.localizedDescription
      }
    }

    if showsIndicator {
      try? await Task.sleep(for: .milliseconds(400))
    }
  }

  func selectProfile(_ profileName: String) {
    selectedProfileName = profileName
    containers = []
    Task { await refresh() }
  }

  func perform(_ action: ProfileAction, profileName: String) async {
    await runOperation("\(action.rawValue.capitalized) \(profileName)") {
      try await service.perform(action, profileName: profileName)
    }
  }

  func perform(_ action: ContainerAction, container: DockerContainer) async {
    await perform(action, containers: [container])
  }

  func perform(_ action: ContainerAction, containers: [DockerContainer]) async {
    let ids = containers.map(\.id)
    await runOperation("\(action.rawValue.capitalized) containers") {
      try await service.perform(action, containerIDs: ids, profileName: selectedProfileName)
    }
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      try launchAtLoginService.setEnabled(enabled)
      launchAtLoginEnabled = launchAtLoginService.isEnabled
      defaults.set(enabled, forKey: Keys.launchAtLoginRequested)
      launchAtLoginError = nil
    } catch {
      launchAtLoginEnabled = launchAtLoginService.isEnabled
      launchAtLoginError = error.localizedDescription
    }
  }

  func setAutoStartColima(_ enabled: Bool) {
    autoStartColima = enabled
  }

  func showDashboard() {
    page = .dashboard
  }

  func showSettings() {
    page = .settings
  }

  func showCleanup() {
    page = .cleanup
    cleanupResultMessage = nil
    Task { await refreshDiskUsage() }
  }

  func setCleanupCategory(_ category: CleanupCategory, selected: Bool) {
    if selected {
      cleanupSelection.insert(category)
    } else {
      cleanupSelection.remove(category)
    }
  }

  func usage(for category: CleanupCategory) -> DockerResourceUsage? {
    guard let type = category.diskUsageType else { return nil }
    return diskUsage.first { $0.type == type }
  }

  func refreshDiskUsage() async {
    guard !isLoadingDiskUsage, selectedProfile?.isRunning == true else { return }
    isLoadingDiskUsage = true
    defer { isLoadingDiskUsage = false }

    do {
      diskUsage = try await service.diskUsage(profileName: selectedProfileName)
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func cleanSelectedResources() async {
    let selection = cleanupSelection
    guard !selection.isEmpty, activeOperation == nil else { return }
    activeOperation = "Cleaning Docker"
    errorMessage = nil

    do {
      let results = try await service.prune(selection, profileName: selectedProfileName)
      cleanupResultMessage = results.map { $0.category.title }.joined(separator: ", ") + " cleaned."
      cleanupSelection.removeAll()
    } catch {
      errorMessage = error.localizedDescription
    }

    activeOperation = nil
    await refresh()
    await refreshDiskUsage()
  }

  func open(_ port: PublishedPort) {
    desktopIntegration.open(port)
  }

  func openMount(_ mount: ContainerMount) {
    handleIntegration { try desktopIntegration.openMount(mount) }
  }

  func openShell(for container: DockerContainer) {
    let endpoint = service.dockerEndpoint(profileName: selectedProfileName)
    handleIntegration {
      try desktopIntegration.openContainerShell(
        container: container,
        endpoint: endpoint
      )
    }
  }

  func openLogs(for container: DockerContainer) {
    let endpoint = service.dockerEndpoint(profileName: selectedProfileName)
    handleIntegration {
      try desktopIntegration.openContainerLogs(container: container, endpoint: endpoint)
    }
  }

  func openColimaShell() {
    handleIntegration { try desktopIntegration.openColimaShell(profileName: selectedProfileName) }
  }

  func copy(_ value: String) {
    desktopIntegration.copy(value)
  }

  func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func runOperation(_ name: String, operation: () async throws -> Void) async {
    guard activeOperation == nil else { return }
    activeOperation = name
    errorMessage = nil
    do {
      try await operation()
    } catch {
      errorMessage = error.localizedDescription
    }
    activeOperation = nil
    await refresh()
  }

  private func handleIntegration(_ operation: () throws -> Void) {
    do {
      try operation()
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private enum Keys {
    static let autoStartColima = "autoStartColima"
    static let launchAtLoginRequested = "launchAtLoginRequested"
  }
}
