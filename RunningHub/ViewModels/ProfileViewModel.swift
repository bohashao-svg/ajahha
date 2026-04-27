import Foundation

// MARK: - Profile Work Item
struct ProfileWorkItem: Identifiable {
    let id: String          // taskId
    let taskId: String
    let workflowId: String?
    let workflowName: String?
    let createdAt: String?
    let outputUrls: [String]
    let firstImageUrl: String?
}

// MARK: - Profile ViewModel
@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var works: [ProfileWorkItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasNext = false

    private var currentPage = 1
    private let pageSize = 20

    // MARK: - Load First Page
    func loadFirstPage() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        works = []
        currentPage = 1
        await fetchPage(1)
        isLoading = false
    }

    // MARK: - Load Next Page
    func loadNextPage() async {
        guard hasNext, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        await fetchPage(currentPage + 1)
        isLoadingMore = false
    }

    // MARK: - Fetch
    private func fetchPage(_ page: Int) async {
        do {
            let result = try await APIService.shared.fetchUserTasks(page: page, size: pageSize)
            let items = result.records.map { record in
                ProfileWorkItem(
                    id: record.taskId,
                    taskId: record.taskId,
                    workflowId: record.workflowId,
                    workflowName: record.workflowName,
                    createdAt: record.createdAt,
                    outputUrls: record.outputUrls,
                    firstImageUrl: record.firstImageUrl
                )
            }
            if page == 1 {
                works = items
            } else {
                works.append(contentsOf: items)
            }
            currentPage = page
            // pages 字段可能为 nil（API 不返回时），用 total/size 兜底
            let totalPages = (result.pages ?? 0) > 0
                ? result.pages!
                : Int(ceil(Double(result.total) / Double(pageSize)))
            hasNext = page < totalPages && !items.isEmpty
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
