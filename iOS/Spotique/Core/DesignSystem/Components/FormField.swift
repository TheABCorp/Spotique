import SwiftUI

/// A labeled input with Spotique styling: a visible label above the control,
/// a hairline border that turns navy on focus, and an error message with an
/// icon below (never color alone).
struct FormField<Content: View>: View {
    let label: String
    var hint: String?
    var error: String?
    var isFocused: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.onSurface)

            content
                .font(.body)
                .foregroundStyle(Color.onSurface)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(borderColor, lineWidth: isFocused || error != nil ? 1.5 : 1)
                }

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.danger)
            } else if let hint {
                Text(hint)
                    .captionStyle()
            }
        }
        .animation(.default, value: error)
    }

    private var borderColor: Color {
        if error != nil { return .danger }
        return isFocused ? .brandNavy : Color.onSurface.opacity(0.25)
    }
}

#Preview("States") {
    VStack(spacing: 24) {
        FormField(label: "First name") {
            TextField("Jane", text: .constant(""))
        }
        FormField(label: "Email", hint: "We'll email you a code.", isFocused: true) {
            TextField("you@example.com", text: .constant("jane@"))
        }
        FormField(label: "Last name", error: "Enter your last name") {
            TextField("Doe", text: .constant(""))
        }
    }
    .padding()
    .background(Color.surface)
}
