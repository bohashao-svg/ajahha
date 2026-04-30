import SwiftUI

// MARK: - Task Center View
struct TaskCenterView: View {
    @StateObject private var vm = TaskCenterViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let tabs: [TaskStatus] = [.running, .queued, .completed, .failed, .cancelled]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabBar
                taskList
            }
            .background(AnimatedMeshBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("任务中心")
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
            }
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { tab in
                    let count = vm.tasks(for: tab).count
                    let isSelected = vm.selectedTab == tab
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(tab.displayName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isSelected ? .white : tab.color)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(
                                        LiquidGlassShape(radius: 6)
                                            .fill(isSelected ? tab.color.opacity(0.7) : tab.color.opacity(0.15))
                                    )
                            }
                        }
                        .foregroundColor(isSelected ? .white : Color(hex: "#8B9CC8"))
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(
                            Group {
                                if isSelected {
                                    LiquidGlassShape(radius: 10)
                                        .fill(
                                            LinearGradient(
                                                colors: [tab.color, tab.color.opacity(0.7)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        )
                                } else {
                                    LiquidGlassShape(radius: 10)
                                        .fill(Color.white.opacity(0.04))
                                }
                            }
                        )
                        .overlay(
                            LiquidGlassShape(radius: 10)
                                .stroke(
                                    isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.08),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: isSelected ? tab.color.opacity(0.35) : .clear, radius: 8, x: 0, y: 0)
                    }
                    .buttonStyle(LiquidButtonStyle())
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minWidth: UIScreen.main.bounds.width)
        }
        .background(
            ZStack {
                Color(hex: "#0D1220").opacity(0.8)
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Task List
    private var taskList: some View {
        let tasks = vm.tasks(for: vm.selectedTab)
        return Group {
            if tasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if vm.selectedTab == .completed && tasks.count > 1 {
                            ExpandingTasksView(tasks: tasks)
                                .frame(height: 320)
                                .padding(.horizontal, 0)
                                .padding(.bottom, 4)
                        }

                        ForEach(tasks) { task in
                            HStack(spacing: 8) {
                                NavigationLink {
                                    TaskDetailView(task: task, vm: vm).environmentObject(appState)
                                } label: {
                                    TaskCardView(task: task)
                                }
                                .buttonStyle(LiquidButtonStyle())

                                if task.isFinished {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            appState.removeTask(id: task.id)
                                        }
                                    } label: {
                                        RHIcon(name: .trash, size: 15, color: Color(hex: "#FF6B6B"))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                LiquidGlassShape(radius: 10)
                                                    .fill(Color(hex: "#FF6B6B").opacity(0.1))
                                            )
                                            .overlay(
                                                LiquidGlassShape(radius: 10)
                                                    .stroke(Color(hex: "#FF6B6B").opacity(0.25), lineWidth: 0.8)
                                            )
                                    }
                                    .buttonStyle(LiquidButtonStyle())
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(16)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: tasks.count)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.selectedTab)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#6C8EFF").opacity(0.08))
                    .frame(width: 80, height: 80)
                    .blur(radius: 12)
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                RHIcon(name: .tasks, size: 30, color: Color(hex: "#6C8EFF").opacity(0.5))
            }
            Text("暂无\(vm.selectedTab.displayName)任务")
                .font(.system(size: 15)).foregroundColor(Color(hex: "#8B9CC8"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
