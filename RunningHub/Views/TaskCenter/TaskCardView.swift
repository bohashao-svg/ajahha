import SwiftUI

// MARK: - Task Card View
struct TaskCardView: View {
    let task: RHTask

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIndicator

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.workflowName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.rhPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(task.createdAt.timeString())
                        .font(.system(size: 11))
                        .foregroundColor(.rhSecondary)
                }

                HStack(spacing: 8) {
                    // Type badge
                    Text(task.workflowType)
                        .font(.system(size: 11))
                        .foregroundColor(.rhSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.rhBackground)
                        .cornerRadius(5)

                    // Plus badge
                    if task.isPlusMode {
                        Text("Plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.rhAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.rhAccent.opacity(0.1))
                            .cornerRadius(5)
                    }

                    // Duck badge
                    if task.isDuckEncoded {
                        RHIcon(name: .duck, size: 12, color: .rhWarning)
                    }

                    Spacer()

                    // Status
                    Text(task.status.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(task.status.color)
                }

                // Progress bar (only when running)
                if task.status == .running {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.rhBorder)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.rhAccent)
                                .frame(width: geo.size.width * task.progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }

            RHIcon(name: .chevron, size: 14, color: .rhBorder)
        }
        .padding(14)
        .background(Color.rhCard)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(task.status.color.opacity(0.15))
                .frame(width: 36, height: 36)

            if task.status == .running {
                ProgressView()
                    .scaleEffect(0.7)
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
        case .running:   EmptyView()
        }
    }
}
