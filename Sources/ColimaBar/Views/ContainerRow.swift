import SwiftUI

struct ContainerRow: View {
  let model: AppModel
  let container: DockerContainer
  @State private var confirmsRemoval = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Circle()
          .fill(container.isRunning ? .green : .secondary.opacity(0.45))
          .frame(width: 8, height: 8)

        VStack(alignment: .leading, spacing: 1) {
          Text(container.name)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
          Text(container.image)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer()
        actionButtons
        moreMenu
      }

      if !container.ports.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(container.ports) { port in
              Button {
                model.open(port)
              } label: {
                Label(port.displayName, systemImage: "network")
                  .font(.caption2)
              }
              .buttonStyle(.bordered)
              .controlSize(.mini)
              .help("Open http://\(port.address)")
            }
          }
        }
        .padding(.leading, 16)
      }
    }
    .padding(10)
    .contentShape(Rectangle())
    .contextMenu { menuContent }
    .alert("Remove \(container.name)?", isPresented: $confirmsRemoval) {
      Button("Remove", role: .destructive) {
        Task { await model.perform(.remove, container: container) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This removes the container. Named volumes and images remain.")
    }
  }

  @ViewBuilder
  private var actionButtons: some View {
    if container.isRunning {
      Button {
        model.openLogs(for: container)
      } label: {
        Image(systemName: "doc.text.magnifyingglass")
      }
      .buttonStyle(.plain)
      .help("Open logs")

      Button {
        model.openShell(for: container)
      } label: {
        Image(systemName: "terminal")
      }
      .buttonStyle(.plain)
      .help("Open shell")
    } else {
      Button {
        Task { await model.perform(.start, container: container) }
      } label: {
        Image(systemName: "play.fill")
      }
      .buttonStyle(.plain)
      .help("Start")
    }
  }

  private var moreMenu: some View {
    Menu {
      menuContent
    } label: {
      Image(systemName: "ellipsis")
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
  }

  @ViewBuilder
  private var menuContent: some View {
    if container.isRunning {
      Button("Stop", systemImage: "stop.fill") {
        Task { await model.perform(.stop, container: container) }
      }
      Button("Restart", systemImage: "arrow.clockwise") {
        Task { await model.perform(.restart, container: container) }
      }
      Divider()
      Button("Open Logs", systemImage: "doc.text.magnifyingglass") {
        model.openLogs(for: container)
      }
      Button("Open Shell", systemImage: "terminal") {
        model.openShell(for: container)
      }
    } else {
      Button("Start", systemImage: "play.fill") {
        Task { await model.perform(.start, container: container) }
      }
    }

    if let mount = container.mounts.first(where: { $0.type == "bind" }) {
      Button("Show Mount in Finder", systemImage: "folder") {
        model.openMount(mount)
      }
    }

    Divider()
    Menu("Copy") {
      Button("Container ID") { model.copy(container.id) }
      Button("Image") { model.copy(container.image) }
      if let service = container.composeService {
        Button("Compose Service") { model.copy(service) }
      }
      ForEach(container.ports) { port in
        Button(port.address) { model.copy(port.address) }
      }
    }
    Divider()
    Button("Remove Container", systemImage: "trash", role: .destructive) {
      confirmsRemoval = true
    }
  }
}
