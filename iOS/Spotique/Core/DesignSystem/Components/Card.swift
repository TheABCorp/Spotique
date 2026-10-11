import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(16)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    Card {
        VStack(alignment: .leading, spacing: 8) {
            Text("35th Avenue, Jackson Heights")
                .font(.headline)
            Text("$5/hr · Driveway")
                .font(.subheadline)
                .foregroundStyle(Color.onSurface.opacity(0.7))
        }
    }
    .padding()
    .background(Color.brandIvory)
}
