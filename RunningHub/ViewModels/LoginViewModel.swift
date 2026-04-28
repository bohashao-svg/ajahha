import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isBlank: Bool { username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty }

    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await APIService.shared.login(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
