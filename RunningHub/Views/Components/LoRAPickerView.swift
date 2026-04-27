import SwiftUI

// MARK: - LoRA Picker View
struct LoRAPickerView: View {
    let onSelect: (PublicResource) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var resources: [PublicResource] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var hasNext = false
    @State private var errorMessage: String?
    @State private var selectedResource: PublicResource?
    @State private var showTriggerAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundColor(.rhError)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    resourceGrid
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 20, color: .rhSecondary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("LoRA 模型库")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.rhPrimary)
                }
            }
        }
        .task { await loadPage(1) }
        .alert("需要触发词", isPresented: $showTriggerAlert, presenting: selectedResource) { res in
            Button("复制触发词") {
                if let tw = res.firstTriggerWords {
                    UIPasteboard.general.string = tw
                }
                onSelect(res)
                dismiss()
            }
            Button("直接使用") {
                onSelect(res)
                dismiss()
            }
            Button("取消", role: .cancel) { selectedResource = nil }
        } message: { res in
            let tw = res.firstTriggerWords ?? ""
            Text("该模型需要触发词才能激活效果：\n\n\(tw)\n\n触发词将自动添加到提示词前面。")
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.rhSecondary)
                TextField("搜索模型名称...", text: $keyword)
                    .font(.system(size: 14))
                    .foregroundColor(.rhPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onSubmit { Task { await loadPage(1) } }
                if !keyword.isEmpty {
                    Button { keyword = ""; Task { await loadPage(1) } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.rhSecondary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.rhCard)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder, lineWidth: 1))

            Button {
                Task { await loadPage(1) }
            } label: {
                if isLoading && currentPage == 1 {
                    ProgressView().frame(width: 40, height: 40)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.rhAccent)
                        .cornerRadius(10)
                }
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Resource Grid
    private var resourceGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(resources, id: \.stableId) { res in
                    ResourceCard(resource: res)
                        .onTapGesture { handleSelect(res) }
                        .onAppear {
                            // 无限加载：最后一个出现时加载下一页
                            if res.stableId == resources.last?.stableId && hasNext && !isLoading {
                                Task { await loadPage(currentPage + 1) }
                            }
                        }
                }
                if isLoading && currentPage > 1 {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .gridCellColumns(3)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Load
    private func loadPage(_ page: Int) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await APIService.shared.fetchPublicResources(
                type: "LORA", keyword: keyword, page: page
            )
            await MainActor.run {
                if page == 1 { resources = result.records }
                else { resources.append(contentsOf: result.records) }
                currentPage = page
                hasNext = result.hasNext ?? false
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Select
    private func handleSelect(_ res: PublicResource) {
        if let tw = res.firstTriggerWords, !tw.isEmpty {
            selectedResource = res
            showTriggerAlert = true
        } else {
            onSelect(res)
            dismiss()
        }
    }
}

// MARK: - Resource Card
private struct ResourceCard: View {
    let resource: PublicResource

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面图
            AsyncImage(url: URL(string: resource.thumbnailUrl ?? resource.posterUrl ?? "")) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .empty:
                    Color.rhCard.overlay(ProgressView().scaleEffect(0.7))
                default:
                    Color.rhCard.overlay(
                        Image(systemName: "photo").font(.system(size: 20)).foregroundColor(.rhBorder)
                    )
                }
            }
            .frame(height: 110)
            .clipped()

            // 名称 + 触发词标记
            VStack(alignment: .leading, spacing: 3) {
                Text(resource.resourceName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.rhPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let tw = resource.firstTriggerWords, !tw.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.rhAccent)
                        Text("有触发词")
                            .font(.system(size: 9))
                            .foregroundColor(.rhAccent)
                    }
                }

                if let baseModel = resource.versions?.first?.baseModel, !baseModel.isEmpty {
                    Text(baseModel)
                        .font(.system(size: 9))
                        .foregroundColor(.rhSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
        }
        .background(Color.rhCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder.opacity(0.5), lineWidth: 1))
        .clipped()
    }
}
