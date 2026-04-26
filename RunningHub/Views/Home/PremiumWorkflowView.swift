import SwiftUI

// MARK: - Premium Workflow View
struct PremiumWorkflowView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var items: [PremiumWorkflowItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var importingId: String?   // workflowId currently being forked
    @State private var importError: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.2).tint(.rhAccent)
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
                        Button("重试") { Task { await loadWorkflows() } }
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

                // Import error toast
                if let err = importError {
                    VStack {
                        Spacer()
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(Color.rhError.opacity(0.9))
                            .cornerRadius(22)
                            .padding(.bottom, 44)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: importError)
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
        let wid = item.workflowId
        let isImporting = importingId == wid

        return Button {
            guard !isImporting else { return }
            Task { await importWorkflow(workflowId: wid) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.rhAccentSoft)
                        .frame(width: 40, height: 40)
                    if isImporting {
                        ProgressView().scaleEffect(0.8).tint(.rhAccent)
                    } else {
                        RHIcon(name: .workflow, size: 18, color: .rhAccent)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    if item.name.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7).tint(.rhSecondary)
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
                    Text(isImporting ? "正在导入..." : wid)
                        .font(.system(size: 11))
                        .foregroundColor(isImporting ? .rhAccent : .rhSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isImporting {
                    EmptyView()
                } else {
                    RHIcon(name: .chevron, size: 12, color: .rhBorder)
                }
            }
            .padding(12)
            .background(Color.rhCard)
            .cornerRadius(14)
            .shadow(color: Color(hex: "#C8392B").opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isImporting)
    }

    // MARK: - Import with auto-fork

    private func importWorkflow(workflowId: String) async {
        importingId = workflowId
        importError = nil

        do {
            // Try direct import first
            let targetId = await forkIfNeeded(workflowId: workflowId)
            await MainActor.run {
                importingId = nil
                onSelect(targetId)
                dismiss()
            }
        }
    }

    /// Try to use workflowId directly; if it fails with NOT_SAVED error, fork it first
    private func forkIfNeeded(workflowId: String) async -> String {
        do {
            // Probe: try fetching detail — if it succeeds the workflow is accessible
            _ = try await APIService.shared.fetchWorkflowDetail(workflowId: workflowId)
            return workflowId
        } catch APIError.serverError(let msg) where msg.contains("NOT_SAVED") || msg.contains("WORKFLOW_NOT") {
            // Workflow not in user's workspace — fork it
            do {
                let newId = try await APIService.shared.duplicateWorkflow(workflowId: workflowId)
                return newId
            } catch {
                await MainActor.run {
                    importingId = nil
                    importError = "导入失败：\(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importError = nil }
                }
                return workflowId
            }
        } catch {
            // Other errors — still try to use the original id
            return workflowId
        }
    }

    // MARK: - Load list

    private func loadWorkflows() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await PremiumWorkflowService.shared.fetchPremiumWorkflows()
            items = fetched
            isLoading = false

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
