import SwiftUI

/// Six digit boxes drawn over one hidden `TextField`, so SMS AutoFill
/// (`.oneTimeCode`) and paste work, and VoiceOver reads it as one control.
struct CodeInputField: View {
    @Binding var code: String
    var length: Int = 6
    var hasError: Bool = false
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        ZStack {
            TextField("6-digit verification code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .opacity(0.02)
                .accessibilityLabel("6-digit verification code")
                .accessibilityValue("\(code.count) of \(length) digits entered")
                .accessibilityIdentifier("auth.codeField")

            ViewThatFits {
                HStack(spacing: 10) { boxes }
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow { ForEach(0..<length / 2, id: \.self, content: box) }
                    GridRow { ForEach(length / 2..<length, id: \.self, content: box) }
                }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    @ViewBuilder
    private var boxes: some View {
        ForEach(0..<length, id: \.self, content: box)
    }

    private func box(at index: Int) -> some View {
        let digit = index < code.count ? String(Array(code)[index]) : ""
        let isCurrent = isFocused && index == min(code.count, length - 1)

        return Text(verbatim: digit)
            .font(.title2.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.onSurface)
            .frame(minWidth: 44, minHeight: 56)
            .background(Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(borderColor(isCurrent: isCurrent), lineWidth: isCurrent || hasError ? 1.5 : 1)
            }
    }

    private func borderColor(isCurrent: Bool) -> Color {
        if hasError { return .danger }
        return isCurrent ? .brandNavy : Color.onSurface.opacity(0.25)
    }
}

#Preview {
    @Previewable @State var code = "482"
    @Previewable @FocusState var isFocused: Bool
    VStack(spacing: 24) {
        CodeInputField(code: $code, isFocused: $isFocused)
        CodeInputField(code: .constant("123456"), hasError: true, isFocused: $isFocused)
    }
    .padding()
    .background(Color.surface)
}
