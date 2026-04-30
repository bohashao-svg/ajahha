import SwiftUI

// MARK: - Task Center View
// Layout: segmented pill tabs → full-width card list
struct TaskCenterView: View {
    @StateObject private var vm = TaskCenterViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let tabs: [TaskStatus] = [.running, .queued, .completed, .failed, .cancelled]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ── Tab pills ────────────────────────────────────────────
                tabPills.padding(.horizontal, 16).padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.06))

                // ── Task list ────────────────────────────────────────────
                taskList
            }
            .background(AnimatedMeshBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("任务中心")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - Tab Pills
    private var tabPills: some View {
        // Use HStack with equal spacing so pills fill the full width evenly
        HStack(spacing: 8) {
            ForEach(tabs, id: \.self) { tab in
                let count = vm.tasks(for: tab).count
                let selected = vm.selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        vm.selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(tab.displayName)
                            .font(.system(size: 12, weight: selected ? .bold : .medium))
                            .lineLimit(1)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(selected ? .white : tab.color)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(selected ? tab.color.opacity(0.5) : tab.color.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(selected ? .white : Color.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(selected ? tab.color : Color.white.opacity(0.07))
                    .clipShape(Capsule())
                    .shadow(color: selected ? tab.color.opacity(0.4) : .clear, radius: 8)
                }
                .buttonStyle(LiquidButtonStyle())
            }
        }
    }

    // MARK: - Task List
    private var taskList: some View {
        let tasks = vm.tasks(for: vm.selectedTab)
        return Group {
            if tasks.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    // Completed tasks: show expanding collection at top
                    if vm.selectedTab == .completed && tasks.count > 1 {
                        ExpandingTasksView(tasks: tasks)
                            .frame(height: 300)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { task in
                            NavigationLink {
                                TaskDetailView(task: task, vm: vm, appState: appState)
                            } label: {
                                TaskCardView(task: task)
                            }
                            .buttonStyle(LiquidButtonStyle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if task.isFinished {
                                    Button(role: .destructive) {
                                        withAnimation { appState.removeTask(id: task.id) }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tasks.count)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.selectedTab)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundColor(Color.white.opacity(0.2))
            Text("暂无\(vm.selectedTab.displayName)任务")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Task Card View
// Layout: left status strip + content + right chevron
struct TaskCardView: View {
    let task: RHTask

    var body: some View {
        HStack(spacing: 0) {
            // Status strip
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(task.status.color)
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 14)
                .shadow(color: task.status.color.opacity(0.6), radius: 4)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(task.workflowName.isEmpty ? task.workflowType : task.workflowName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(task.createdAt.timeString())
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.3))
                }

                HStack(spacing: 6) {
                    // Type badge
                    Text(task.workflowType)
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.45))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())

                    // Plus badge
                    if task.isPlusMode {
                        Text("✦ Plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#FFD166"))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color(hex: "#FFD166").opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // Status label with morphing animation
                    MorphingText(
                        task.status.displayName,
                        effect: .evaporate,
                        font: .systemFont(ofSize: 11, weight: .semibold),
                        textColor: task.status.uiColor
                    )
                    .frame(height: 18)
                }

                // Progress bar (running only)
                if task.status == .running {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08)).frame(height: 3)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#6C8EFF"), Color(hex: "#4ECDC4")],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * task.progress, height: 3)
                                .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 3)
                                .animation(.easeInOut(duration: 0.4), value: task.progress)
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 14)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.2))
                .padding(.trailing, 14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
