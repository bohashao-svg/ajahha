import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showLoginAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                if let err = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text(err).font(.system(size: 14)).foregroundColor(.rhError)
                        Button("重试") { Task { await vm.loadPage(1) } }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.rhAccent)
                    }
                } else {
                    outputList
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
                    Text("我的作品")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .onAppear {
            if !StorageService.shared.isLoggedIn {
                showLoginAlert = true
            } else {
                Task { await vm.loadPage(1) }
            }
        }
        .alert("请先登录", isPresented: $showLoginAlert) {
            Button("确定") { dismiss() }
        } message: {
            Text("查看个人作品需要先登录账号")
        }
    }

    private var outputList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.outputs) { item in
                    OutputCard(item: item)
                        .onAppear {
                            if item.id == vm.outputs.last?.id && vm.hasNext && !vm.isLoading {
                                Task { await vm.loadPage(vm.currentPage + 1) }
                            }
                        }
                }
                if vm.isLoading {
                    ProgressView().padding()
                }
            }
            .padding(16)
        }
    }
}

struct OutputCard: View {
    let item: OutputHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: item.outputUrl ?? "")) { phase in
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
            .frame(width: 80, height: 80)
            .cornerRadius(10).clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(item.taskName ?? "未命名")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.rhPrimary)
                    .lineLimit(1)

                Text(item.createTime ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.rhSecondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(item.status))
                        .frame(width: 6, height: 6)
                    Text(statusText(item.status))
                        .font(.system(size: 11))
                        .foregroundColor(statusColor(item.status))
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.rhCard)
        .cornerRadius(12)
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.uppercased() {
        case "SUCCESS": return .rhSuccess
        case "FAILED": return .rhError
        default: return .rhSecondary
        }
    }

    private func statusText(_ status: String?) -> String {
        switch status?.uppercased() {
        case "SUCCESS": return "成功"
        case "FAILED": return "失败"
        default: return status ?? "未知"
        }
    }
}
