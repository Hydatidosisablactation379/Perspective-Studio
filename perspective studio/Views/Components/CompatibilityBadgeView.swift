import SwiftUI

struct CompatibilityBadgeView: View {
    let compatibility: RAMService.Compatibility

    private var color: Color {
        switch compatibility {
        case .comfortable: .green
        case .tight: .orange
        case .incompatible: .red
        case .unknown: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: compatibility.systemImage)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(compatibility.rawValue)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(.capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compatibility.accessibilityLabel)
    }
}
