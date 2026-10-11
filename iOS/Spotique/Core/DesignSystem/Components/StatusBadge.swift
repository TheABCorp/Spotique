import SwiftUI

struct StatusBadge: View {
    let status: BookingStatus

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
            .accessibilityLabel(Text(accessibilityText))
    }

    private var label: String {
        switch status {
        case .pending: String(localized: "Pending")
        case .confirmed: String(localized: "Confirmed")
        case .declined: String(localized: "Declined")
        case .cancelled: String(localized: "Cancelled")
        case .completed: String(localized: "Completed")
        case .unknown: String(localized: "Unknown")
        }
    }

    private var icon: String {
        switch status {
        case .pending: "clock"
        case .confirmed: "checkmark.circle"
        case .declined: "xmark.circle"
        case .cancelled: "minus.circle"
        case .completed: "checkmark.seal"
        case .unknown: "questionmark.circle"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .pending: .brandCharcoal
        case .confirmed: .success
        case .declined, .cancelled: .danger
        case .completed: .brandNavy
        case .unknown: .brandCharcoal
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }

    private var accessibilityText: String {
        String(localized: "Status: \(label)")
    }
}

#Preview("All Statuses") {
    VStack(spacing: 12) {
        StatusBadge(status: .pending)
        StatusBadge(status: .confirmed)
        StatusBadge(status: .declined)
        StatusBadge(status: .cancelled)
        StatusBadge(status: .completed)
        StatusBadge(status: .unknown)
    }
    .padding()
}
