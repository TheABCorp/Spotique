import SwiftUI

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.danger)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let retry {
                Button(String(localized: "Retry"), action: retry)
                    .font(.subheadline.weight(.semibold))
                    .tint(.brandNavy)
            }
        }
        .padding(12)
        .background(Color.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

#Preview("With Retry") {
    ErrorBanner(message: "Something went wrong.") {}
        .padding()
}

#Preview("Without Retry") {
    ErrorBanner(message: "No internet connection.")
        .padding()
}
