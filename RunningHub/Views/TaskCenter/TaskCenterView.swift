import SwiftUI

// MARK: - Task Center View
struct TaskCenterView: View {
    @StateObject private var vm = TaskCenterViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let tabs: [TaskStatus] = [.running, .queued, .completed, .failed, .cancelled]

    var body: some View {
        NavigationView {
            ZStack {
                Color.rhBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    tabBar
                    taskList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("任务中心")
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 20, color: .rhSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    let count = vm.tasks(for: tab).count
                    let isSelected = vm.selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
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
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? tab.color.opacity(0.7) : tab.color.opacity(0.12))
                                    .cornerRadius(6)
                            }
                        }
                        .foregroundColor(isSelected ? .white : .rhSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            isSelected
                                ? LinearGradient(colors: [tab.color, tab.color.opacity(0.8)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.clear, Color.clear],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(12)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: UIScreen.main.bounds.width)
        }
        .background(Color.rhCard)
        .shadow(color: Color(hex: "#C8392B").opacity(0.05), radius: 6, x: 0, y: 2)
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
                        ForEach(tasks) { task in
                            HStack(spacing: 8) {
                                NavigationLink {
                                    TaskDetailView(task: task, vm: vm)
                                        .environmentObject(appState)
                                } label: {
                                    TaskCardView(task: task)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                if task.isFinished {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            appState.removeTask(id: task.id)
                                        }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.rhError.opacity(0.08))
                                                .frame(width: 38, height: 38)
                                            RHIcon(name: .trash, size: 15, color: .rhError)
                                        }
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(16)
                    .animation(.easeInOut(duration: 0.22), value: tasks.count)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.selectedTab)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.rhAccentSoft)
                    .frame(width: 72, height: 72)
                RHIcon(name: .tasks, size: 32, color: .rhAccent.opacity(0.4))
            }
            Text("暂无\(vm.selectedTab.displayName)任务")
                .font(.system(size: 15))
                .foregroundColor(.rhSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
