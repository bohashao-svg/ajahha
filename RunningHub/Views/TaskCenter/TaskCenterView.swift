import SwiftUI

// MARK: - Task Center View
struct TaskCenterView: View {
    @StateObject private var vm = TaskCenterViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private let tabs: [TaskStatus] = [.running, .queued, .pending, .completed, .failed, .cancelled]

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
            HStack(spacing: 8) {
                ForEach(tabs, id: \.self) { tab in
                    let count = vm.tasks(for: tab).count
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(tab.displayName)
                                .font(.system(size: 13, weight: vm.selectedTab == tab ? .semibold : .regular))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(vm.selectedTab == tab ? .white : tab.color)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(vm.selectedTab == tab ? tab.color : tab.color.opacity(0.15))
                                    .cornerRadius(6)
                            }
                        }
                        .foregroundColor(vm.selectedTab == tab ? .white : .rhSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(vm.selectedTab == tab ? tab.color : Color.clear)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.rhCard)
    }

    // MARK: - Task List
    private var taskList: some View {
        let tasks = vm.tasks(for: vm.selectedTab)
        return Group {
            if tasks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tasks) { task in
                            HStack(spacing: 8) {
                                NavigationLink {
                                    TaskDetailView(task: task, vm: vm)
                                        .environmentObject(appState)
                                } label: {
                                    TaskCardView(task: task)
                                }
                                .buttonStyle(.plain)

                                if task.isFinished {
                                    Button {
                                        appState.removeTask(id: task.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 15))
                                            .foregroundColor(.rhError)
                                            .frame(width: 36, height: 36)
                                            .background(Color.rhError.opacity(0.1))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            RHIcon(name: .tasks, size: 48, color: .rhBorder)
            Text("暂无\(vm.selectedTab.displayName)任务")
                .font(.system(size: 15))
                .foregroundColor(.rhSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
