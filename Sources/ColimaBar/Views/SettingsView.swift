import SwiftUI

struct SettingsView: View {
  let model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Settings")
          .font(.title2.weight(.semibold))

        VStack(spacing: 0) {
          SettingsToggleRow(
            title: "Launch at Login",
            detail: "Keep Colima Bar in the menu bar after you sign in.",
            value: Binding(
              get: { model.launchAtLoginEnabled },
              set: { model.setLaunchAtLogin($0) }
            )
          )
          Divider().padding(.leading, 42)
          SettingsToggleRow(
            title: "Start Colima on Launch",
            detail: "Start the selected profile when Colima Bar opens.",
            value: Binding(
              get: { model.autoStartColima },
              set: { model.setAutoStartColima($0) }
            )
          )
        }
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))

        if let error = model.launchAtLoginError {
          Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Installed Tools")
            .font(.headline)
          LabeledContent("Colima", value: "Required")
          LabeledContent("Docker CLI", value: "Docker profiles")
          LabeledContent("Ghostty", value: "Logs and shells")
          LabeledContent("Refresh", value: "Every 5 seconds")
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
      }
      .padding(16)
    }
  }
}

private struct SettingsToggleRow: View {
  let title: String
  let detail: String
  @Binding var value: Bool

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.medium))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Toggle("", isOn: $value)
        .labelsHidden()
        .toggleStyle(.switch)
    }
    .padding(12)
  }
}
