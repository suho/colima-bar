import SwiftUI

struct FooterView: View {
  let model: AppModel

  var body: some View {
    HStack {
      if let date = model.lastRefreshed {
        Text("Updated \(date, style: .relative) ago")
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        Text("Waiting for Colima")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Quit") {
        model.quit()
      }
      .buttonStyle(.borderless)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
  }
}
