import SwiftUI

struct DownloadProgressView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress) {
                Text("Downloading...")
                    .font(.caption)
            }
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Downloading model, \(Int(progress * 100)) percent complete")
    }
}
