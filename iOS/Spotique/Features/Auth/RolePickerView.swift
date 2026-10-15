import SwiftUI

/// Choose how you'll use Spotique. Radio-style rows: the selected one gets a
/// filled icon, bold text, and the `.isSelected` trait, never color alone.
struct RolePickerView: View {
    @Binding var selection: UserRole?
    var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How will you use Spotique?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.onSurface)
                .accessibilityAddTraits(.isHeader)

            ForEach(UserRole.allCases, id: \.self) { role in
                row(for: role)
            }

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.danger)
            } else {
                Text("You can change this later in Settings.")
                    .captionStyle()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func row(for role: UserRole) -> some View {
        let isSelected = selection == role
        return Button {
            selection = role
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.brandNavy : Color.onSurface.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.title)
                        .font(isSelected ? .body.weight(.semibold) : .body)
                    Text(role.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color.onSurface.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Color.onSurface)
            .padding(14)
            .frame(minHeight: 44)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.brandNavy : Color.onSurface.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("auth.role.\(role.rawValue)")
    }
}

extension UserRole {
    var title: String {
        switch self {
        case .host: String(localized: "I have a spot to rent")
        case .driver: String(localized: "I need parking")
        case .both: String(localized: "Both")
        }
    }

    var subtitle: String {
        switch self {
        case .host: String(localized: "List your driveway or garage by the hour.")
        case .driver: String(localized: "Find and book private parking nearby.")
        case .both: String(localized: "Rent out your spot and park elsewhere.")
        }
    }
}

#Preview {
    @Previewable @State var role: UserRole? = .driver
    RolePickerView(selection: $role)
        .padding()
        .background(Color.surface)
}
