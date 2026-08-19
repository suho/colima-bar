import SwiftUI

struct EmptyStateView: View {
  let model: AppModel

  var body: some View {
    ContentUnavailableView {
      Label("No Colima Profile", systemImage: "shippingbox")
    } description: {
      Text("Start the default profile with your installed Colima CLI.")
    } actions: {
      Button("Start Colima") {
        Task { await model.perform(.start, profileName: "default") }
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct StoppedStateView: View {
  let model: AppModel

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      Image(systemName: "pause.circle")
        .font(.system(size: 42))
        .foregroundStyle(.secondary)
      VStack(spacing: 4) {
        Text("Colima is Stopped")
          .font(.headline)
        Text("Start \(model.selectedProfileName) to use containers.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Button("Start Colima") {
        Task { await model.perform(.start, profileName: model.selectedProfileName) }
      }
      .buttonStyle(.borderedProminent)
      .disabled(model.activeOperation != nil)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct UnsupportedRuntimeView: View {
  let profile: ColimaProfile?

  var body: some View {
    ContentUnavailableView {
      Label("\((profile?.runtime ?? "Runtime").capitalized) Profile", systemImage: "shippingbox")
    } description: {
      Text("VM controls are available. Container controls currently require a Docker profile.")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
