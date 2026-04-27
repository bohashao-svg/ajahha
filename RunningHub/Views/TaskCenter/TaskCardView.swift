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
                        .foregroundColor(.rhPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(task.createdAt.timeString())
                        .font(.system(size: 11))
                        .foregroundColor(.rhSecondary)
                }

                HStack(spacing: 6) {
                    // Type badge
                    Text(task.workflowType)
                        .font(.system(size: 11))
                        .foregroundColor(.rhSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.rhBackground)
                        .cornerRadius(7)

                    if task.isPlusMode {
                        HStack(spacing: 3) {
                            Text("✦")
                                .font(.system(size: 9))
                            Text("Plus")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.rhGold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.rhGold.opacity(0.1))
                        .cornerRadius(7)
                    }

                    if task.isDuckEncoded {
                        RHIcon(name: .duck, size: 12, color: .rhGold)
                    }
                    if task.isTTEncoded {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 11))
                            .foregroundColor(.rhAccent)
                    }

                    Spacer()

                    // Status badge
                    Text(task.status.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(task.status.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(task.status.color.opacity(0.1))
                        .cornerRadius(7)
                }

                if task.status == .running {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.rhBorder)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(colors: [Color(hex: "#C8392B"), Color.rhGold],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: geo.size.width * task.progress, height: 4)
                                .animation(.easeInOut(duration: 0.4), value: task.progress)
                        }
                    }
                    .frame(height: 4)
                }
            }

            RHIcon(name: .chevron, size: 12, color: .rhBorder)
        }
        .padding(14)
        .background(Color.rhCard)
        .cornerRadius(18)
        .shadow(color: Color(hex: "#C8392B").opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private var statusIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(task.status.color.opacity(0.1))
                .frame(width: 40, height: 40)

            if task.status == .running {
                ProgressView()
                    .scaleEffect(0.75)
                    .tint(task.status.color)
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
