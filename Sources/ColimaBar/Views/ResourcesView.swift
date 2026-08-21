import SwiftUI

struct ResourcesView: View {
  let model: AppModel
  @State private var confirmsPrune = false
  @State private var confirmsRemoveAll = false

  private var kind: ResourceKind { model.selectedResourceKind }

  var body: some View {
    VStack(spacing: 0) {
      picker
      Divider()
      list
      Divider()
      actionBar
    }
    .confirmationDialog(
      "Remove unused \(kind.title.lowercased())?",
      isPresented: $confirmsPrune,
      titleVisibility: .visible
    ) {
      Button("Prune Unused", role: .destructive) {
        Task { await model.pruneUnused(kind) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("\(kind.pruneDetail) This cannot be undone.")
    }
    .confirmationDialog(
      "\(kind.removeAllTitle)?",
      isPresented: $confirmsRemoveAll,
      titleVisibility: .visible
    ) {
      Button("Remove \(removableCount) \(kind.itemNoun(removableCount))", role: .destructive) {
        Task { await model.removeAllResources(of: kind) }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("\(kind.removeAllDetail) This cannot be undone.")
    }
  }

  private var picker: some View {
    VStack(spacing: 8) {
      Picker(
        "Resource",
        selection: Binding(
          get: { model.selectedResourceKind },
          set: { model.selectResourceKind($0) }
        )
      ) {
        ForEach(ResourceKind.allCases) { kind in
          Text(kind.shortTitle).tag(kind)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      HStack(spacing: 6) {
        Text(summary)
          .font(.caption)
          .foregroundStyle(.secondary)
        if model.isLoadingResources || model.isLoadingDiskUsage {
          ProgressView().controlSize(.small).scaleEffect(0.7)
        }
        Spacer(minLength: 0)
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 10)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var list: some View {
    if items.isEmpty {
      ContentUnavailableView(
        "No \(kind.title)",
        systemImage: kind.systemImage,
        description: Text(kind.emptyDescription)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            ResourceRow(item: item, model: model)
            if index < items.count - 1 {
              Divider().padding(.leading, 27)
            }
          }
        }
      }
    }
  }

  private var items: [ResourceItem] {
    switch kind {
    case .containers:
      return model.containers.map { container in
        ResourceItem(
          id: container.id,
          title: container.name,
          subtitle: container.image,
          trailing: container.statusDisplayName,
          isActive: container.isRunning,
          badge: nil,
          copyValue: container.id
        )
      }
    case .images:
      return model.images.map { image in
        ResourceItem(
          id: image.id,
          title: image.displayName,
          subtitle: [image.shortID, image.createdSince]
            .compactMap { $0 }
            .joined(separator: " · "),
          trailing: image.size,
          isActive: (image.usedByContainerCount ?? 0) > 0,
          badge: imageBadge(image),
          copyValue: image.imageID
        )
      }
    case .volumes:
      return model.volumes.map { volume in
        let used = volume.linkCount ?? model.containerCount(usingVolume: volume.name)
        return ResourceItem(
          id: volume.id,
          title: volume.name,
          subtitle: volume.mountpoint ?? volume.driver ?? "",
          trailing: volume.sizeDisplayName,
          isActive: used > 0,
          badge: used > 0 ? "in use" : nil,
          copyValue: volume.name
        )
      }
    case .buildCache:
      return model.buildCache.map { record in
        ResourceItem(
          id: record.id,
          title: record.displayName,
          subtitle: [record.type, record.lastUsedAt.map { "used \($0)" }]
            .compactMap { $0 }
            .joined(separator: " · "),
          trailing: record.size,
          isActive: !record.isReclaimable,
          badge: cacheBadge(record),
          copyValue: record.id
        )
      }
    case .networks:
      return model.networks.map { network in
        ResourceItem(
          id: network.id,
          title: network.name,
          subtitle: [network.shortID, network.driver, network.scope]
            .compactMap { $0 }
            .joined(separator: " · "),
          trailing: nil,
          isActive: false,
          badge: network.isPredefined ? "predefined" : nil,
          copyValue: network.networkID
        )
      }
    }
  }

  private var actionBar: some View {
    VStack(spacing: 8) {
      if let message = model.resourceResultMessage {
        Label(message, systemImage: "checkmark.circle.fill")
          .font(.caption)
          .foregroundStyle(.green)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack(spacing: 8) {
        Button("Prune Unused", systemImage: "sparkles") {
          confirmsPrune = true
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
        .help(kind.pruneDetail)

        Button("Remove All", systemImage: "trash", role: .destructive) {
          confirmsRemoveAll = true
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .frame(maxWidth: .infinity)
        .disabled(removableCount == 0)
        .help(kind.removeAllDetail)
      }
      .disabled(model.activeOperation != nil)
    }
    .padding(12)
  }

  private func cacheBadge(_ record: DockerBuildCacheRecord) -> String? {
    if !record.isReclaimable { return "in use" }
    return record.isShared ? "shared" : nil
  }

  private func imageBadge(_ image: DockerImage) -> String? {
    if let used = image.usedByContainerCount, used > 0 { return "in use" }
    return image.isUntagged ? "dangling" : nil
  }

  private var removableCount: Int {
    model.removableCount(for: kind)
  }

  private var summary: String {
    let count = model.resourceCount(for: kind)
    var parts = ["\(count) \(kind.itemNoun(count))"]
    if let usage = model.usage(for: kind.cleanupCategory) {
      parts.append(usage.size)
      parts.append("\(usage.reclaimable) reclaimable")
    }
    return parts.joined(separator: " · ")
  }
}

private struct ResourceItem: Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let trailing: String?
  let isActive: Bool
  let badge: String?
  let copyValue: String
}

private struct ResourceRow: View {
  let item: ResourceItem
  let model: AppModel

  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(item.isActive ? Color.green : Color.secondary.opacity(0.3))
        .frame(width: 7, height: 7)

      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 5) {
          Text(item.title)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .truncationMode(.middle)
          if let badge = item.badge {
            Text(badge)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .padding(.horizontal, 5)
              .padding(.vertical, 1)
              .background(.quaternary, in: Capsule())
              .fixedSize()
          }
        }
        if !item.subtitle.isEmpty {
          Text(item.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }

      Spacer(minLength: 8)

      if let trailing = item.trailing, !trailing.isEmpty {
        Text(trailing)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .fixedSize()
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .contextMenu {
      Button("Copy Name") { model.copy(item.title) }
      Button("Copy ID") { model.copy(item.copyValue) }
    }
  }
}
