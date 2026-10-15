import SwiftUI

struct ProfileCompletionView: View {
    @State private var viewModel: ProfileCompletionViewModel
    @FocusState private var focus: ProfileCompletionViewModel.Field?

    init(viewModel: ProfileCompletionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tell us about yourself")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.onSurface)
                            .accessibilityAddTraits(.isHeader)
                        Text("Just a few details to finish setting up your account.")
                            .bodyStyle()
                    }

                    nameFields
                    addressFields
                    RolePickerView(selection: $viewModel.role, error: viewModel.error(for: .role))

                    if let failure = viewModel.failure {
                        ErrorBanner(message: failure.message)
                    }

                    PrimaryButton(title: String(localized: "Finish sign-up"), isLoading: viewModel.state == .submitting) {
                        focus = nil
                        Task { await viewModel.submit() }
                    }
                    .disabled(!viewModel.canSubmit)
                    .accessibilityIdentifier("auth.finish")
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sign out") { Task { await viewModel.signOut() } }
                }
            }
            .onChange(of: viewModel.failure) { _, failure in
                guard let failure else { return }
                AccessibilityNotification.Announcement(failure.message).post()
            }
        }
    }

    // MARK: - Sections

    private var nameFields: some View {
        VStack(spacing: 16) {
            field(.firstName, label: String(localized: "First name"), text: $viewModel.firstName, content: .givenName, next: .lastName)
            field(.lastName, label: String(localized: "Last name"), text: $viewModel.lastName, content: .familyName, next: .street)
        }
    }

    private var addressFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Home address")
                .font(.headline)
                .foregroundStyle(Color.onSurface)
            Text("Used to set up your account.")
                .captionStyle()
            field(.street, label: String(localized: "Street"), text: $viewModel.street, content: .streetAddressLine1, next: .city)
            field(.city, label: String(localized: "City"), text: $viewModel.city, content: .addressCity, next: .state)
            HStack(alignment: .top, spacing: 12) {
                field(.state, label: String(localized: "State"), text: $viewModel.stateCode, content: .addressState, next: .zip)
                field(.zip, label: String(localized: "ZIP code"), text: $viewModel.zip, content: .postalCode, next: nil)
                    .keyboardType(.numberPad)
            }
        }
    }

    private func field(
        _ field: ProfileCompletionViewModel.Field,
        label: String,
        text: Binding<String>,
        content: UITextContentType,
        next: ProfileCompletionViewModel.Field?
    ) -> some View {
        FormField(label: label, error: viewModel.error(for: field), isFocused: focus == field) {
            TextField(label, text: text)
                .textContentType(content)
                .textInputAutocapitalization(field == .state ? .characters : .words)
                .autocorrectionDisabled()
                .submitLabel(next == nil ? .done : .next)
                .focused($focus, equals: field)
                .onSubmit { focus = next }
                .onChange(of: text.wrappedValue) { viewModel.clearServerError(for: field) }
        }
    }
}

#Preview {
    ProfileCompletionView(viewModel: ProfileCompletionViewModel(
        authService: PreviewAuthService(),
        sessionStore: .preview
    ))
}

#Preview("Large text") {
    ProfileCompletionView(viewModel: ProfileCompletionViewModel(
        authService: PreviewAuthService(),
        sessionStore: .preview
    ))
    .dynamicTypeSize(.accessibility2)
}
