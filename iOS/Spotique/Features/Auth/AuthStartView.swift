import SwiftUI

struct AuthStartView: View {
    @Bindable var viewModel: AuthStartViewModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                Picker("Sign in with", selection: $viewModel.selectedMedium) {
                    Text("Phone").tag(AuthMedium.phone)
                    Text("Email").tag(AuthMedium.email)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("auth.medium")

                destinationField

                if let failure = viewModel.failure {
                    ErrorBanner(message: failure.message)
                        .accessibilityIdentifier("auth.error")
                }

                PrimaryButton(title: String(localized: "Continue"), isLoading: viewModel.state == .sending) {
                    submit()
                }
                .disabled(!viewModel.canSubmit)
                .accessibilityIdentifier("auth.continue")

                Text(footerText)
                    .captionStyle()
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.surface.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.failure) { _, failure in
            guard let failure else { return }
            AccessibilityNotification.Announcement(failure.message).post()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spotique")
                .font(.largeTitle.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(Color.brandNavy)
                .accessibilityAddTraits(.isHeader)

            Rectangle()
                .fill(Color.brandGold)
                .frame(width: 40, height: 2)
                .accessibilityHidden(true)

            Text("Sign in or create an account")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.onSurface)

            Text("Private parking in Jackson Heights, by the hour.")
                .bodyStyle()
        }
        .padding(.top, 32)
    }

    @ViewBuilder
    private var destinationField: some View {
        switch viewModel.selectedMedium {
        case .phone:
            FormField(label: String(localized: "Phone number"), hint: String(localized: "US numbers only"), isFocused: isFieldFocused) {
                HStack(spacing: 10) {
                    Text(verbatim: "+1")
                        .foregroundStyle(Color.onSurface.opacity(0.7))
                        .accessibilityHidden(true)
                    TextField("(347) 555-1234", text: $viewModel.phoneInput)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($isFieldFocused)
                        .accessibilityLabel("Phone number, US only")
                        .accessibilityIdentifier("auth.phoneField")
                }
            }
        case .email:
            FormField(label: String(localized: "Email"), isFocused: isFieldFocused) {
                TextField("you@example.com", text: $viewModel.emailInput)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .onSubmit(submit)
                    .focused($isFieldFocused)
                    .accessibilityIdentifier("auth.emailField")
            }
        }
    }

    private var footerText: String {
        switch viewModel.selectedMedium {
        case .phone: String(localized: "We'll text you a 6-digit code. Message and data rates may apply.")
        case .email: String(localized: "We'll email you a 6-digit code.")
        }
    }

    private func submit() {
        guard viewModel.canSubmit else { return }
        isFieldFocused = false
        Task { await viewModel.sendCode() }
    }
}

#Preview("Phone") {
    NavigationStack {
        AuthStartView(viewModel: AuthStartViewModel(authService: PreviewAuthService()))
    }
}

#Preview("Email, offline error") {
    let viewModel = AuthStartViewModel(authService: PreviewAuthService(failure: .offline))
    viewModel.selectedMedium = .email
    viewModel.emailInput = "jane@example.com"
    return NavigationStack {
        AuthStartView(viewModel: viewModel)
    }
    .task { await viewModel.sendCode() }
}

#Preview("Large text") {
    NavigationStack {
        AuthStartView(viewModel: AuthStartViewModel(authService: PreviewAuthService()))
    }
    .dynamicTypeSize(.accessibility2)
}
