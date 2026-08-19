import SwiftUI

struct ContainerListView: View {
  let model: AppModel

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 14) {
        ProfileSummaryView(model: model)

        if model.containers.isEmpty {
          ContentUnavailableView(
            "No Containers",
            systemImage: "shippingbox",
            description: Text("Containers for this profile appear here.")
          )
          .frame(height: 240)
        } else {
          ForEach(model.groups) { group in
            ContainerGroupView(model: model, group: group)
          }
        }
      }
      .padding(12)
    }
  }
}

private struct ProfileSummaryView: View {
  let model: AppModel

  var body: some View {
    if let profile = model.selectedProfile {
      VStack(spacing: 10) {
        HStack(spacing: 12) {
          StatView(value: "\(profile.cpus)", label: "CPU")
          StatView(value: profile.memoryDisplayName, label: "Memory")
          StatView(value: profile.diskDisplayName, label: "Disk")
          StatView(value: profile.arch, label: "Arch")
        }
        Divider()
        HStack {
          Label(profile.runtime.capitalized, systemImage: "cube")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Button("Ghostty", systemImage: "terminal") {
            model.openColimaShell()
          }
          .buttonStyle(.borderless)
          Button("Restart", systemImage: "arrow.clockwise") {
            Task { await model.perform(.restart, profileName: profile.name) }
          }
          .buttonStyle(.borderless)
          Button("Stop", systemImage: "stop.fill") {
            Task { await model.perform(.stop, profileName: profile.name) }
          }
          .buttonStyle(.borderless)
        }
      }
      .padding(10)
      .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }
  }
}

private struct StatView: View {
  let value: String
  let label: String

  var body: some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.caption.weight(.semibold))
        .lineLimit(1)
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }
}
