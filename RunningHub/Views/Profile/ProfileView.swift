import SwiftUI

// MARK: - Profile View
struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    profileHeaderCard
                    outputsSection
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .background(AnimatedMeshBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("我的作品")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        GlassIconButton(icon: .close, size: 18, color: Color(hex: "#8B9CC8"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await vm.loadPage(1) } } label: {
                        GlassIconButton(icon: .refresh, size: 18, color: Color(hex: "#8B9CC8"))
                    }
                }
            }
            .task { await vm.loadPage(1) }
        }
    }

    // MARK: - Profile Header Card
    private var profileHeaderCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF").opacity(0.3), Color(hex: "#A78BFA").opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.3), radius: 12)
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("我的作品集")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#4ECDC4")).frame(width: 7, height: 7)
                        .shadow(color: Color(hex: "#4ECDC4").opacity(0.6), radius: 4)
                    Text("已登录").font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(vm.outputs.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("作品").font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
            }
        }
        .padding(16)
        .glassCard(radius: 20)
    }

    // MARK: - Outputs Section
    private var outputsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3, height: 14)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 4)
                Text("生成历史")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                Spacer()
                Text("\(vm.outputs.count) 条")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }

            if vm.isLoading && vm.outputs.isEmpty {
                ForEach(0..<4, id: \.self) { _ in
                    OutputCardSkeleton()
                }
            } else if vm.outputs.isEmpty {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.04)).frame(width: 60, height: 60)
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.8))
                        RHIcon(name: .image, size: 26, color: Color(hex: "#8B9CC8").opacity(0.5))
                    }
                    Text("暂无生成记录").font(.system(size: 14)).foregroundColor(Color(hex: "#8B9CC8"))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.outputs) { item in
                        NavigationLink {
                            // Build a synthetic RHTask so TaskDetailView's duck/TT decode works
                            TaskDetailView(
                                task: item.asRHTask(),
                                vm: TaskCenterViewModel()
                            )
                            .environmentObject(AppState.shared)
                        } label: {
                            OutputHistoryRow(item: item)
                        }
                        .buttonStyle(LiquidButtonStyle())
                    }
                    if vm.hasNext {
                        Button { Task { await vm.loadPage(vm.currentPage + 1) } } label: {
                            HStack(spacing: 6) {
                                if vm.isLoading { ProgressView().scaleEffect(0.7) }
                                Text("加载更多").font(.system(size: 13)).foregroundColor(Color(hex: "#6C8EFF"))
                            }
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(LiquidGlassShape(radius: 10).fill(Color(hex: "#6C8EFF").opacity(0.08)))
                            .overlay(LiquidGlassShape(radius: 10).stroke(Color(hex: "#6C8EFF").opacity(0.2), lineWidth: 0.8))
                        }
                        .buttonStyle(LiquidButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Output History Row
struct OutputHistoryRow: View {
    let item: OutputHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            if let url = item.filePreviewUrl ?? item.fileUrl {
                RHRemoteImage(url: url, contentMode: .fill, cornerRadius: 10)
                    .frame(width: 60, height: 60)
            } else {
                ZStack {
                    LiquidGlassShape(radius: 10).fill(Color(hex: "#6C8EFF").opacity(0.1)).frame(width: 60, height: 60)
                    RHIcon(name: .image, size: 24, color: Color(hex: "#6C8EFF").opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.taskName ?? "生成结果")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#F0F4FF")).lineLimit(1)
                if let t = item.createTime {
                    Text(t).font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                }
            }

            Spacer()
            RHIcon(name: .chevron, size: 12, color: Color(hex: "#8B9CC8").opacity(0.4))
        }
        .padding(12)
        .glassCard(radius: 14)
    }
}
