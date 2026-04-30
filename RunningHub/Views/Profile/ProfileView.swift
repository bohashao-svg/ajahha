import SwiftUI

// MARK: - Profile View
struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedMeshBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        profileHeaderCard
                        if vm.isLoading {
                            ForEach(0..<3, id: \.self) { _ in
                                ResourceCardSkeleton()
                            }
                        } else {
                            workflowsSection
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
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
                    Button { Task { await vm.refresh() } } label: {
                        GlassIconButton(icon: .refresh, size: 18, color: Color(hex: "#8B9CC8"))
                    }
                }
            }
            .task { await vm.loadWorkflows() }
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

                Text(vm.userInitial)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#F0F4FF"), Color(hex: "#8B9CC8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.username)
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
                Text("\(vm.workflowCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                Text("工作流").font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
            }
        }
        .padding(16)
        .glassCard(radius: 20)
    }

    // MARK: - Workflows Section
    private var workflowsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                LiquidGlassShape(radius: 2)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#A78BFA")],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3, height: 14)
                    .shadow(color: Color(hex: "#6C8EFF").opacity(0.6), radius: 4)
                Text("我的工作流")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                Spacer()
                Text("\(vm.workflows.count) 个")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "#8B9CC8"))
            }

            if vm.workflows.isEmpty && !vm.isLoading {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.04)).frame(width: 60, height: 60)
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 0.8))
                        RHIcon(name: .workflow, size: 26, color: Color(hex: "#8B9CC8").opacity(0.5))
                    }
                    Text("暂无工作流").font(.system(size: 14)).foregroundColor(Color(hex: "#8B9CC8"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.workflows) { workflow in
                        WorkflowProfileRow(workflow: workflow)
                    }
                }
            }
        }
    }
}

// MARK: - Workflow Profile Row
struct WorkflowProfileRow: View {
    let workflow: WorkflowListItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                LiquidGlassShape(radius: 12)
                    .fill(Color(hex: "#6C8EFF").opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(LiquidGlassShape(radius: 12).stroke(Color(hex: "#6C8EFF").opacity(0.2), lineWidth: 0.6))
                RHIcon(name: .workflow, size: 20, color: Color(hex: "#6C8EFF"))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(workflow.workflowName ?? workflow.workflowId)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#F0F4FF"))
                    .lineLimit(1)
                Text(workflow.workflowId)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#8B9CC8"))
                    .lineLimit(1)
            }

            Spacer()

            RHIcon(name: .chevron, size: 12, color: Color(hex: "#8B9CC8").opacity(0.4))
        }
        .padding(12)
        .glassCard(radius: 14)
    }
}
