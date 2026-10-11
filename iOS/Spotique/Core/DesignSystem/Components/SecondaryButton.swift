import SwiftUI

struct SecondaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(.brandNavy)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(.brandNavy)
        .disabled(isLoading)
    }
}

#Preview("Normal") {
    SecondaryButton(title: "Cancel") {}
        .padding()
}
