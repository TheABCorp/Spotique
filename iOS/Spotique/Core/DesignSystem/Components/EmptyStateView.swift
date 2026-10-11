import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
                .foregroundStyle(Color.brandNavy)
        } description: {
            Text(message)
                .foregroundStyle(Color.onSurface.opacity(0.7))
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .tint(.brandNavy)
            }
        }
    }
}

#Preview("With Action") {
    EmptyStateView(
        icon: "car.fill",
        title: "No Bookings Yet",
        message: "Your upcoming and past bookings will appear here.",
        actionTitle: "Find a Spot"
    ) {}
}

#Preview("Without Action") {
    EmptyStateView(
        icon: "star",
        title: "No Ratings",
        message: "You haven't received any ratings yet."
    )
}
