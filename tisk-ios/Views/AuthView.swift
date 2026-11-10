import SwiftUI

struct AuthView: View {
    @Environment(AuthStore.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @FocusState private var focused: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 6 && !auth.isWorking
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 6) {
                Text("tisk")
                    .font(.system(size: 44, weight: .bold))
                Text(isSignUp ? "Create your account" : "Sign in to your tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .glassEffect(.regular.interactive(), in: .capsule)

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focused, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let info = auth.infoMessage {
                Text(info)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: submit) {
                Group {
                    if auth.isWorking {
                        ProgressView()
                    } else {
                        Text(isSignUp ? "Create account" : "Sign in")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .controlSize(.large)
            .disabled(!canSubmit)

            HStack(spacing: 12) {
                Rectangle().fill(.quaternary).frame(height: 1)
                Text("or")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Rectangle().fill(.quaternary).frame(height: 1)
            }

            Button {
                focused = nil
                Task { await auth.signInWithGoogle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Continue with Google")
                        .font(.headline)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(auth.isWorking)

            Button(isSignUp ? "I already have an account" : "Create an account") {
                isSignUp.toggle()
                auth.errorMessage = nil
                auth.infoMessage = nil
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .sensoryFeedback(.error, trigger: auth.errorMessage) { _, new in new != nil }
    }

    private func submit() {
        guard canSubmit else { return }
        focused = nil
        let email = email.trimmingCharacters(in: .whitespaces)
        Task {
            if isSignUp {
                await auth.signUp(email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthStore())
}
