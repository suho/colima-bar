import SwiftUI

struct ContainerGroupView: View {
  let model: AppModel
  let group: ContainerGroup

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: group.isComposeProject ? "square.3.layers.3d" : "cube")
          .foregroundStyle(.secondary)
        Text(group.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text("\(group.containers.count)")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
        Spacer()

        Menu {
          Button("Start Project", systemImage: "play.fill") {
            Task { await model.perform(.start, containers: group.containers) }
          }
          Button("Stop Project", systemImage: "stop.fill") {
            Task { await model.perform(.stop, containers: group.containers.filter(\.isRunning)) }
          }
          Button("Restart Project", systemImage: "arrow.clockwise") {
            Task { await model.perform(.restart, containers: group.containers.filter(\.isRunning)) }
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
      }

      VStack(spacing: 0) {
        ForEach(Array(group.containers.enumerated()), id: \.element.id) { index, container in
          ContainerRow(model: model, container: container)
          if index < group.containers.count - 1 {
            Divider().padding(.leading, 30)
          }
        }
      }
      .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }
  }
}
