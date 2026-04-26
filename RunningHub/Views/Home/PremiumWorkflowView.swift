import SwiftUI

// MARK: - Premium Workflow View
struct PremiumWorkflowView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PremiumWorkflowItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.rhAccent)
                        Text("加载精品工作流...")
                            .font(.system(size: 14))
                            .foregroundColor(.rhSecondary)
                    }
                } else if let err = errorMessage {
                    VStack(spacing: 16) {
                        RHIcon(name: .close, size: 32, color: .rhError.opacity(0.5))
                        Text(err)
                            .font(.system(size: 14))
                            .foregroundColor(.rhSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("重试") {
                            Task { await loadWorkflows() }
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.rhAccent)
                    }
                } else if items.isEmpty {
                    VStack(spacing: 16) {
                        RHIcon(name: .workflow, size: 32, color: .rhSecondary.opacity(0.4))
                        Text("暂无精品工作流")
                            .font(.system(size: 14))
                            .foregroundColor(.rhSecondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(items.indices, id: \.self) { index in
                                workflowRow(index: index)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("精品工作流")
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 20, color: .rhSecondary)
                    }
                }
            }
        }
        .task { await loadWorkflows() }
    }

    private func workflowRow(index: Int) -> some View {
        let item = items[index]
        let workflowId = item.workflowId

        return Button {
            onSelect(workflowId)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.rhAccentSoft)
                        .frame(width: 40, height: 40)
                    RHIcon(name: .workflow, size: 18, color: .rhAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if item.name.isEmpty {
                        // Still loading name
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.rhSecondary)
                            Text("加载中...")
                                .font(.system(size: 13))
                                .foregroundColor(.rhSecondary)
                        }
                    } else {
                        Text(item.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.rhPrimary)
                            .lineLimit(1)
                    }
                    Text(workflowId)
                        .font(.system(size: 11))
                        .foregroundColor(.rhSecondary)
                        .lineLimit(1)
                }

                Spacer()

                RHIcon(name: .chevron, size: 12, color: .rhBorder)
            }
            .padding(12)
            .background(Color.rhCard)
            .cornerRadius(14)
            .shadow(color: Color(hex: "#C8392B").opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func loadWorkflows() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await PremiumWorkflowService.shared.fetchPremiumWorkflows()
            items = fetched
            isLoading = false

            // Concurrently fetch names for all items
            await withTaskGroup(of: (Int, String).self) { group in
                for (index, item) in fetched.enumerated() {
                    group.addTask {
                        let name = (try? await PremiumWorkflowService.shared.fetchWorkflowName(workflowId: item.workflowId)) ?? item.workflowId
                        return (index, name)
                    }
                }
                for await (index, name) in group {
                    if index < items.count {
                        items[index].name = name
                    }
                }
            }
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
            isLoading = false
        }
    }
}
