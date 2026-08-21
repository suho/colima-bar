import SwiftUI

struct HeaderView: View {
  let model: AppModel

  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "shippingbox.fill")
          .font(.title2)
          .foregroundStyle(.tint)

        VStack(alignment: .leading, spacing: 1) {
          Text("Colima Bar")
            .font(.headline)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        if model.isShowingRefreshIndicator || model.activeOperation != nil {
          ProgressView()
            .controlSize(.small)
        }

        Button {
          Task { await model.refreshFromUser() }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .help("Refresh")
        .disabled(model.isShowingRefreshIndicator || model.activeOperation != nil)

        if model.page == .dashboard {
          if model.selectedProfile?.isRunning == true && model.selectedProfile?.runtime == "docker"
          {
            Button {
              model.showResources()
            } label: {
              Image(systemName: "square.stack.3d.up")
            }
            .buttonStyle(.plain)
            .help("Docker Resources")

            Button {
              model.showCleanup()
            } label: {
              Image(systemName: "trash.slash")
            }
            .buttonStyle(.plain)
            .help("Docker Cleanup")
          }

          Button {
            model.showSettings()
          } label: {
            Image(systemName: "gearshape")
          }
          .buttonStyle(.plain)
          .help("Settings")
        } else {
          Button {
            model.showDashboard()
          } label: {
            Image(systemName: "shippingbox")
          }
          .buttonStyle(.plain)
          .help("Back")
        }
      }

      if model.profiles.count > 1 && model.page == .dashboard {
        Picker(
          "Profile",
          selection: Binding(
            get: { model.selectedProfileName },
            set: { model.selectProfile($0) }
          )
        ) {
          ForEach(model.profiles) { profile in
            Text(profile.name).tag(profile.name)
          }
        }
        .pickerStyle(.segmented)
      }
    }
    .padding(12)
  }

  private var subtitle: String {
    if let operation = model.activeOperation { return operation }
    guard let profile = model.selectedProfile else { return "Colima not detected" }
    if profile.isRunning {
      return "\(profile.name) · \(model.runningContainerCount) running"
    }
    return "\(profile.name) · \(profile.statusDisplayName)"
  }
}
