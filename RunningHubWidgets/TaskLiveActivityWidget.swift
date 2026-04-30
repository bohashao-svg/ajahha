import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Widget
// Displays task status on the lock screen and Dynamic Island.
// Requires iOS 16.2+.

@main
struct RunningHubWidgets: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TaskActivityAttributes.self) { context in
            // Lock screen / StandBy view
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    statusIcon(state: context.state)
                        .font(.system(size: 18))
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.isFinished {
                        Text("\(context.state.progressPercent)%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.taskName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(context.state.statusText)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                statusIcon(state: context.state)
                    .font(.system(size: 14))
            } compactTrailing: {
                if context.state.isFinished {
                    Text(context.state.isSuccess ? "完成" : "失败")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(context.state.isSuccess ? .green : .red)
                } else {
                    Text("\(context.state.progressPercent)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            } minimal: {
                statusIcon(state: context.state)
                    .font(.system(size: 12))
            }
        }
    }

    @ViewBuilder
    private func statusIcon(state: TaskActivityAttributes.ContentState) -> some View {
        if state.isFinished {
            Image(systemName: state.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(state.isSuccess ? .green : .red)
        } else {
            Image(systemName: "sparkles")
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Lock Screen View
private struct LockScreenView: View {
    let state: TaskActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 3) {
                Text(state.taskName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(state.statusText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            // Progress or checkmark
            if !state.isFinished {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: CGFloat(state.progressPercent) / 100)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                    Text("\(state.progressPercent)%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.05, green: 0.07, blue: 0.12))
        )
    }

    private var iconName: String {
        if state.isFinished {
            return state.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        return "sparkles"
    }

    private var iconColor: Color {
        if state.isFinished {
            return state.isSuccess ? .green : .red
        }
        return .blue
    }

    private var iconBackground: Color {
        if state.isFinished {
            return state.isSuccess
                ? Color.green.opacity(0.15)
                : Color.red.opacity(0.15)
        }
        return Color.blue.opacity(0.15)
    }
}
