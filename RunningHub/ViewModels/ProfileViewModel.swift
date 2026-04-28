import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var outputs: [OutputHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasNext = false

    func loadPage(_ page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIService.shared.fetchOutputHistory(page: page)
            if page == 1 {
                outputs = result.records
            } else {
                outputs.append(contentsOf: result.records)
            }
            currentPage = page

            if let total = result.total?.intValue, let pages = result.pages?.intValue {
                hasNext = page < pages
            } else {
                hasNext = !result.records.isEmpty
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
