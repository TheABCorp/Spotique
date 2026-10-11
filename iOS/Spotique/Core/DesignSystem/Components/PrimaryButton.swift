import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .tint(.brandIvory)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(.brandNavy)
        .disabled(isLoading)
    }
}

#Preview("Normal") {
    PrimaryButton(title: "Sign In") {}
        .padding()
}

#Preview("Loading") {
    PrimaryButton(title: "Sign In", isLoading: true) {}
        .padding()
}

#Preview("Disabled") {
    PrimaryButton(title: "Sign In") {}
        .disabled(true)
        .padding()
}
