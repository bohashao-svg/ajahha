import SwiftUI

// MARK: - Liquid Glass Shimmer
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.white.opacity(0.12), location: 0.35),
                            .init(color: Color.white.opacity(0.22), location: 0.5),
                            .init(color: Color.white.opacity(0.12), location: 0.65),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .init(x: phase, y: 0.3),
                        endPoint: .init(x: phase + 1, y: 0.7)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .animation(.linear(duration: 1.8).repeatForever(autoreverses: false), value: phase)
                }
                .allowsHitTesting(false)
            )
            .onAppear { phase = 1 }
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
