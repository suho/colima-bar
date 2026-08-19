import SwiftUI

struct DockerCleanupView: View {
  let model: AppModel
  @State private var confirmsCleanup = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text("Docker Cleanup")
              .font(.title2.weight(.semibold))
            Text("Remove resources that Docker is not using.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          if model.isLoadingDiskUsage {
            ProgressView().controlSize(.small)
          }
        }

        VStack(spacing: 0) {
          ForEach(Array(CleanupCategory.allCases.enumerated()), id: \.element.id) {
            index, category in
            CleanupCategoryRow(model: model, category: category)
            if index < CleanupCategory.allCases.count - 1 {
              Divider().padding(.leading, 42)
            }
          }
        }
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))

        if let message = model.cleanupResultMessage {
          Label(message, systemImage: "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.green)
        }

        Text("Cleanup is permanent. Docker keeps active containers and resources attached to them.")
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Clean Selected", systemImage: "trash", role: .destructive) {
          confirmsCleanup = true
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .frame(maxWidth: .infinity)
        .disabled(model.cleanupSelection.isEmpty || model.activeOperation != nil)
      }
      .padding(16)
    }
    .confirmationDialog(
      "Clean selected Docker resources?",
      isPresented: $confirmsCleanup,
      titleVisibility: .visible
    ) {
      Button("Clean Resources", role: .destructive) {
        Task { await model.cleanSelectedResources() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This action cannot be undone. Only the selected resource types are pruned.")
    }
  }
}

private struct CleanupCategoryRow: View {
  let model: AppModel
  let category: CleanupCategory

  var body: some View {
    Toggle(
      isOn: Binding(
        get: { model.cleanupSelection.contains(category) },
        set: { model.setCleanupCategory(category, selected: $0) }
      )
    ) {
      HStack(spacing: 10) {
        Image(systemName: category.systemImage)
          .frame(width: 20)
          .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text(category.title)
              .font(.subheadline.weight(.medium))
            Spacer()
            if let usage = model.usage(for: category) {
              Text(usageSummary(usage))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          Text(category.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
    }
    .toggleStyle(.checkbox)
    .padding(11)
  }

  private func usageSummary(_ usage: DockerResourceUsage) -> String {
    if let count = usage.unusedCount {
      return "\(count) · \(usage.reclaimable)"
    }
    return usage.reclaimable
  }
}
