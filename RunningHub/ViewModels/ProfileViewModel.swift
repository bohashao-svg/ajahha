import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var outputs: [OutputHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPage = 1
    @Published var hasNext = false

    private var lastRequestedPage: Int?

    func loadPage(_ page: Int) async {
        guard !isLoading else { return }
        guard lastRequestedPage != page else { return }

        isLoading = true
        lastRequestedPage = page
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIService.shared.fetchOutputHistory(page: page)
            if page == 1 {
                outputs = result.records
            } else {
                let existingIds = Set(outputs.compactMap { $0.id })
                let newRecords = result.records.filter { item in
                    guard let id = item.id else { return true }
                    return !existingIds.contains(id)
                }
                outputs.append(contentsOf: newRecords)
            }
            currentPage = page
            hasNext = result.hasNext ?? (!result.records.isEmpty)
        } catch {
            errorMessage = error.localizedDescription
            lastRequestedPage = nil
        }
    }

    func resetPagination() {
        lastRequestedPage = nil
    }
}
