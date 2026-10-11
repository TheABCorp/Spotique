import SwiftUI

struct LoadingOverlay: View {
    var message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.brandNavy)

                if let message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.onSurface)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message ?? String(localized: "Loading")))
    }
}

#Preview {
    ZStack {
        Color.brandIvory.ignoresSafeArea()
        Text("Background content")
        LoadingOverlay(message: "Saving...")
    }
}
