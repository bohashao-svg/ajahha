import SwiftUI

// MARK: - Task Card View
struct TaskCardView: View {
    let task: RHTask

    var body: some View {
        HStack(spacing: 12) {
            statusIndicator

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(task.workflowName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#F0F4FF"))
                        .lineLimit(1)
                    Spacer()
                    Text(task.createdAt.timeString())
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#8B9CC8"))
                }

                HStack(spacing: 6) {
                    Text(task.workflowType)
                        .font(.system(size: 11)).foregroundColor(Color(hex: "#8B9CC8"))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(LiquidGlassShape(radius: 7).fill(Color.white.opacity(0.05)))
                        .overlay(LiquidGlassShape(radius: 7).stroke(Color.white.opacity(0.08), lineWidth: 0.6))

                    if task.isPlusMode {
                        HStack(spacing: 3) {
                            Text("✦").font(.system(size: 9))
                            Text("Plus").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#FFD166"))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(LiquidGlassShape(radius: 7).fill(Color(hex: "#FFD166").opacity(0.1)))
                        .overlay(LiquidGlassShape(radius: 7).stroke(Color(hex: "#FFD166").opacity(0.25), lineWidth: 0.6))
                        .shadow(color: Color(hex: "#FFD166").opacity(0.2), radius: 4)
                    }

                    if task.isDuckEncoded { RHIcon(name: .duck, size: 12, color: Color(hex: "#FFD166")) }
                    if task.isTTEncoded {
                        Image(systemName: "wand.and.stars").font(.system(size: 11)).foregroundColor(Color(hex: "#6C8EFF"))
                    }

                    Spacer()

                    MorphingText(
                        task.status.displayName,
                        effect: .evaporate,
                        font: .systemFont(ofSize: 11, weight: .semibold),
                        textColor: task.status.uiColor
                    )
                    .frame(height: 20)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(LiquidGlassShape(radius: 7).fill(task.status.color.opacity(0.1)))
                    .overlay(LiquidGlassShape(radius: 7).stroke(task.status.color.opacity(0.2), lineWidth: 0.6))
                    .shadow(color: task.status.color.opacity(0.2), radius: 4)
                }

                if task.status == .running {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            LiquidGlassShape(radius: 3)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 4)
                            LiquidGlassShape(radius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#6C8EFF"), Color(hex: "#4ECDC4")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * task.progress, height: 4)
                                .shadow(color: Color(hex: "#6C8EFF").opacity(0.5), radius: 4)
                                .animation(.easeInOut(duration: 0.4), value: task.progress)
                        }
                    }
                    .frame(height: 4)
                }
            }

            RHIcon(name: .chevron, size: 12, color: Color(hex: "#8B9CC8").opacity(0.4))
        }
        .padding(14)
        .glassCard(radius: 16)
    }

    private var statusIndicator: some View {
        ZStack {
            LiquidGlassShape(radius: 12)
                .fill(task.status.color.opacity(0.1))
                .frame(width: 42, height: 42)
                .overlay(
                    LiquidGlassShape(radius: 12)
                        .stroke(task.status.color.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(color: task.status.color.opacity(0.2), radius: 6)

            if task.status == .running {
                ProgressView().scaleEffect(0.75).tint(task.status.color)
            } else {
                statusIcon
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch task.status {
        case .completed: RHIcon(name: .check, size: 16, color: task.status.color)
        case .failed:    RHIcon(name: .close, size: 16, color: task.status.color)
        case .cancelled: RHIcon(name: .close, size: 16, color: task.status.color)
        case .queued:    RHIcon(name: .refresh, size: 16, color: task.status.color)
        case .pending:   RHIcon(name: .refresh, size: 16, color: task.status.color)
        case .running:   EmptyView()
        }
    }
}
