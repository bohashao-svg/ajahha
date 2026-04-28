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
                    Text("任务中心").font(.system(size: 17, weight: .bold)).foregroundColor(.rhPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        RHIcon(name: .close, size: 18, color: .rhPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.rhCard)
                            .clipShape(SketchRoundedRect(radius: 8))
                            .overlay(SketchRoundedRect(radius: 8).stroke(Color.rhInk.opacity(0.2), lineWidth: 1.5))
                            .shadow(color: Color.rhInk.opacity(0.1), radius: 0, x: 2, y: 2)
                    }
                }
            }
        }
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs, id: \.self) { tab in
                    let count = vm.tasks(for: tab).count
                    let isSelected = vm.selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.selectedTab = tab }
                    } label: {
                        HStack(spacing: 5) {
                            Text(tab.displayName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isSelected ? .white : tab.color)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(isSelected ? tab.color.opacity(0.7) : tab.color.opacity(0.15))
                                    .clipShape(SketchRoundedRect(radius: 6))
                            }
                        }
                        .foregroundColor(isSelected ? .white : .rhSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(isSelected ? tab.color : Color.clear)
                        .clipShape(SketchRoundedRect(radius: 10))
                        .overlay(
                            SketchRoundedRect(radius: 10)
                                .stroke(isSelected ? tab.color : Color.rhInk.opacity(0.12), lineWidth: isSelected ? 0 : 1.2)
                        )
                        .shadow(color: isSelected ? tab.color.opacity(0.25) : .clear, radius: 0, x: 2, y: 2)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minWidth: UIScreen.main.bounds.width)
        }
        .background(Color.rhCard)
        .overlay(Rectangle().frame(height: 1.5).foregroundColor(Color.rhInk.opacity(0.1)), alignment: .bottom)
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
                                    TaskDetailView(task: task, vm: vm).environmentObject(appState)
                                } label: {
                                    TaskCardView(task: task)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                if task.isFinished {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) { appState.removeTask(id: task.id) }
                                    } label: {
                                        RHIcon(name: .trash, size: 15, color: .rhError)
                                            .frame(width: 38, height: 38)
                                            .background(Color.rhRedMuted)
                                            .clipShape(SketchRoundedRect(radius: 10))
                                            .overlay(SketchRoundedRect(radius: 10).stroke(Color.rhError.opacity(0.3), lineWidth: 1.2))
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
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.rhRedMuted).frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.rhAccent.opacity(0.2), lineWidth: 1.5))
                RHIcon(name: .tasks, size: 30, color: .rhAccent.opacity(0.5))
            }
            Text("暂无\(vm.selectedTab.displayName)任务")
                .font(.system(size: 15)).foregroundColor(.rhSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
