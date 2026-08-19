import AppKit
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = AppModel()
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let popover = NSPopover()

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureStatusItem()
    configurePopover()
    observeStatus()

    if CommandLine.arguments.contains("--show-popover") {
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(500))
        self?.togglePopover(nil)
      }
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    NSStatusBar.system.removeStatusItem(statusItem)
  }

  @objc private func togglePopover(_ sender: Any?) {
    guard let button = statusItem.button else { return }
    if popover.isShown {
      popover.performClose(sender)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      popover.contentViewController?.view.window?.makeKey()
    }
  }

  private func configureStatusItem() {
    guard let button = statusItem.button else { return }
    button.target = self
    button.action = #selector(togglePopover(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    button.toolTip = "Colima Bar"
    updateStatusIcon()
  }

  private func configurePopover() {
    popover.behavior = .transient
    popover.animates = true
    updatePopoverSize()
    popover.contentViewController = NSHostingController(rootView: MenuBarContentView(model: model))
  }

  private func observeStatus() {
    withObservationTracking {
      _ = model.statusSymbol
      _ = model.runningContainerCount
      _ = model.selectedProfile?.status
      _ = model.page
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.updateStatusIcon()
        self?.updatePopoverSize()
        self?.observeStatus()
      }
    }
  }

  private func updateStatusIcon() {
    guard let button = statusItem.button else { return }
    let image = NSImage(
      systemSymbolName: model.statusSymbol, accessibilityDescription: "Colima Bar")
    image?.isTemplate = true
    button.image = image

    if let profile = model.selectedProfile {
      button.toolTip =
        "Colima \(profile.statusDisplayName) · \(model.runningContainerCount) running"
    } else {
      button.toolTip = "Colima Bar"
    }
  }

  private func updatePopoverSize() {
    let height: CGFloat = model.page == .cleanup ? 520 : 440
    popover.contentSize = NSSize(width: 390, height: height)
  }
}

@main
struct ColimaBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
