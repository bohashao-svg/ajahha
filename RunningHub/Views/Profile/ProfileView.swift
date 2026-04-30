import SwiftUI

// MARK: - Profile View
// Layout: compact header strip → masonry/waterfall output grid
struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header strip ─────────────────────────────────────
                    headerStrip.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16)

                    // ── Grid ─────────────────────────────────────────────
                    if vm.isLoading && vm.outputs.isEmpty {
                        skeletonGrid
                    } else if vm.outputs.isEmpty {
                        emptyState
                    } else {
                        outputGrid
                    }

                    // Load more
                    if vm.hasNext {
                        Button { Task { await vm.loadPage(vm.currentPage + 1) } } label: {
                            HStack(spacing: 6) {
                                if vm.isLoading { ProgressView().scaleEffect(0.7).tint(Color(hex: "#6C8EFF")) }
                                Text("加载更多").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "#6C8EFF"))
                            }
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(Color(hex: "#6C8EFF").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(LiquidButtonStyle())
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }

                    Spacer(minLength: 30)
                }
            }
            .background(AnimatedMeshBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("我的作品").font(.system(size: 17, weight: .black, design: .rounded)).foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundColor(Color.white.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await vm.loadPage(1) } } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 15, weight: .medium)).foregroundColor(Color.white.opacity(0.6))
                    }
                }
            }
            .task { await vm.loadPage(1) }
        }
        .environmentObject(AppState.shared)
    }

    // MARK: - Header Strip
    private var headerStrip: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.fill")
                    .font(.system(size: 20)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("我的作品集").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle().fill(Color(hex: "#4ECDC4")).frame(width: 6, height: 6)
                        .shadow(color: Color(hex: "#4ECDC4").opacity(0.8), radius: 3)
                    Text("已登录").font(.system(size: 12)).foregroundColor(Color.white.opacity(0.45))
                }
            }
            Spacer()
            // Count badge
            VStack(spacing: 2) {
                Text("\(vm.outputs.count)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                Text("作品").font(.system(size: 11)).foregroundColor(Color.white.opacity(0.35))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Output Grid
    private var outputGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(vm.outputs) { item in
                NavigationLink {
                    TaskDetailView(task: item.asRHTask(), vm: TaskCenterViewModel(), appState: AppState.shared)
                } label: {
                    outputCell(item)
                }
                .buttonStyle(LiquidButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }

    private func outputCell(_ item: OutputHistoryItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Image
            Group {
                if let url = item.filePreviewUrl ?? item.fileUrl {
                    RHRemoteImage(url: url, contentMode: .fill, cornerRadius: 14)
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(Image(systemName: "photo").font(.system(size: 24, weight: .ultraLight)).foregroundColor(Color.white.opacity(0.2)))
                }
            }
            .frame(height: 160)
            .clipped()

            // Bottom gradient + label
            LinearGradient(colors: [.clear, Color.black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(item.taskName ?? "生成结果")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 10).padding(.bottom, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Skeleton Grid
    private var skeletonGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 160)
                    .shimmer()
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundColor(Color.white.opacity(0.15))
            Text("还没有生成记录").font(.system(size: 15)).foregroundColor(Color.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}
