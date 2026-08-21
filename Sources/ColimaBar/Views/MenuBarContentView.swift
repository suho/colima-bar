import SwiftUI

struct MenuBarContentView: View {
  let model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      HeaderView(model: model)
      Divider()

      if let error = model.errorMessage {
        ErrorBanner(message: error)
          .padding(.horizontal, 12)
          .padding(.top, 10)
      }

      content
    }
    .frame(width: 390, height: model.page == .cleanup ? 520 : 440)
    .background(.regularMaterial)
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        await model.refresh(silent: true)
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    if model.page == .settings {
      SettingsView(model: model)
    } else if model.page == .cleanup {
      DockerCleanupView(model: model)
    } else if model.profiles.isEmpty {
      EmptyStateView(model: model)
    } else if model.selectedProfile?.isRunning != true {
      StoppedStateView(model: model)
    } else if model.selectedProfile?.runtime != "docker" {
      UnsupportedRuntimeView(profile: model.selectedProfile)
    } else {
      ContainerListView(model: model)
    }
  }
}

private struct ErrorBanner: View {
  let message: String

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      Text(message)
        .font(.caption)
        .lineLimit(3)
      Spacer(minLength: 0)
    }
    .padding(10)
    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
  }
}
