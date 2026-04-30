import SwiftUI

// MARK: - Liquid Glass Shimmer
// Uses a moving mask instead of animating gradient endpoints,
// which avoids per-frame gradient recalculation.
struct ShimmerModifier: ViewModifier {
    @State private var moveRight: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: Color.white.opacity(0.18), location: 0.4),
                                    .init(color: Color.white.opacity(0.28), location: 0.5),
                                    .init(color: Color.white.opacity(0.18), location: 0.6),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * 0.55)
                        .offset(x: moveRight ? w * 1.2 : -w * 0.6)
                        .animation(
                            .linear(duration: 1.6).repeatForever(autoreverses: false),
                            value: moveRight
                        )
                }
                .allowsHitTesting(false)
                .clipped()
            )
            .onAppear { moveRight = true }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton block (glass style)
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 6

    var body: some View {
        LiquidGlassShape(radius: cornerRadius)
            .fill(Color.white.opacity(0.06))
            .frame(width: width, height: height)
            .overlay(
                LiquidGlassShape(radius: cornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shimmer()
    }
}

// MARK: - OutputCard Skeleton
struct OutputCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            LiquidGlassShape(radius: 12)
                .fill(Color.white.opacity(0.06))
                .frame(width: 80, height: 80)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 120, height: 14)
                SkeletonBlock(width: 80, height: 11)
                SkeletonBlock(width: 50, height: 11)
            }
            Spacer()
        }
        .padding(12)
        .glassCard(radius: 14)
    }
}

// MARK: - LoRA Resource Card Skeleton
struct ResourceCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LiquidGlassShape(radius: 0)
                .fill(Color.white.opacity(0.06))
                .frame(height: 110)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 11)
                SkeletonBlock(width: 60, height: 9)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
        }
        .glassCard(radius: 12)
        .clipped()
    }
}

// MARK: - Workflow Row Skeleton
struct WorkflowRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            LiquidGlassShape(radius: 10)
                .fill(Color.white.opacity(0.06))
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 140, height: 14)
                SkeletonBlock(width: 90, height: 11)
            }
            Spacer()
        }
        .padding(12)
        .glassCard(radius: 14)
    }
}

// MARK: - App Node Row Skeleton
struct AppNodeRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBlock(width: 100, height: 13)
            SkeletonBlock(height: 40, cornerRadius: 10)
        }
    }
}

// MARK: - Node Form Card Skeleton
struct NodeFormCardSkeleton: View {
    var count: Int = 3
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(width: 60, height: 14)
            ForEach(0..<count, id: \.self) { i in
                AppNodeRowSkeleton()
                if i < count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .glassCard(radius: 16)
    }
}
