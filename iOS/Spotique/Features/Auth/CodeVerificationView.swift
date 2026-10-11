import SwiftUI

struct CodeVerificationView: View {
    @State private var viewModel: CodeVerificationViewModel
    @FocusState private var isCodeFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(viewModel: CodeVerificationViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter your code")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.onSurface)
                        .accessibilityAddTraits(.isHeader)
                    Text("We sent a 6-digit code to \(viewModel.maskedDestination).")
                        .bodyStyle()
                }

                CodeInputField(code: $viewModel.code, hasError: viewModel.failure != nil, isFocused: $isCodeFocused)

                if let failure = viewModel.failure {
                    ErrorBanner(message: failure.message)
                        .accessibilityIdentifier("auth.error")
                }

                PrimaryButton(title: String(localized: "Verify"), isLoading: viewModel.state == .verifying) {
                    Task { await viewModel.verify() }
                }
                .disabled(!viewModel.canVerify)
                .accessibilityIdentifier("auth.verify")

                resendButton

                Button(viewModel.usesPhone ? "Use a different phone number" : "Use a different email") {
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .tint(.brandNavy)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isCodeFocused = true }
        .onChange(of: viewModel.code) { _, code in
            if code.count == CodeVerificationViewModel.codeLength {
                Task { await viewModel.verify() }
            }
        }
        .onChange(of: viewModel.failure) { _, failure in
            guard let failure else { return }
            AccessibilityNotification.Announcement(failure.message).post()
            isCodeFocused = true
        }
    }

    /// Redraws each second so the countdown label stays current.
    private var resendButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = viewModel.secondsUntilResend(at: context.date)
            SecondaryButton(
                title: seconds > 0
                    ? String(localized: "Resend code (\(seconds)s)")
                    : String(localized: "Resend code"),
                isLoading: viewModel.state == .resending
            ) {
                Task { await viewModel.resend() }
            }
            .disabled(!viewModel.canResend(at: context.date))
            .accessibilityIdentifier("auth.resend")
        }
    }
}

#Preview("Phone") {
    NavigationStack {
        CodeVerificationView(viewModel: .preview())
    }
}

#Preview("Invalid code, large text") {
    let viewModel = CodeVerificationViewModel.preview(failure: .invalidCode)
    viewModel.code = "123456"
    return NavigationStack {
        CodeVerificationView(viewModel: viewModel)
    }
    .dynamicTypeSize(.accessibility2)
}

#if DEBUG
extension CodeVerificationViewModel {
    static func preview(failure: AuthFailure? = nil) -> CodeVerificationViewModel {
        let service = PreviewAuthService(failure: failure)
        return CodeVerificationViewModel(
            pending: PendingVerification(destination: .phone("+13475551234"), maskedDestination: "+1347***1234"),
            authService: service,
            sessionStore: .preview
        )
    }
}
#endif
