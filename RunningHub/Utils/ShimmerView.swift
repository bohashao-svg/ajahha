import SwiftUI

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.45), location: 0.4),
                            .init(color: .white.opacity(0.45), location: 0.6),
                            .init(color: .clear, location: 1)
                        ]),
                        startPoint: .init(x: phase, y: 0.5),
                        endPoint: .init(x: phase + 1, y: 0.5)
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: phase)
                }
                .allowsHitTesting(false)
            )
            .onAppear {
                phase = 1
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton block
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.rhBorder.opacity(0.5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - OutputCard Skeleton
struct OutputCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.rhBorder.opacity(0.5))
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
        .background(Color.rhCard)
        .cornerRadius(12)
    }
}

// MARK: - LoRA Resource Card Skeleton (3-column grid)
struct ResourceCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.rhBorder.opacity(0.5))
                .frame(height: 110)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 11)
                SkeletonBlock(width: 60, height: 9)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
        }
        .background(Color.rhCard)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.rhBorder.opacity(0.5), lineWidth: 1))
        .clipped()
    }
}

// MARK: - Workflow Row Skeleton (list row)
struct WorkflowRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.rhBorder.opacity(0.5))
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 140, height: 14)
                SkeletonBlock(width: 90, height: 11)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.rhCard)
        .cornerRadius(14)
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
                if i < count - 1 { Divider().padding(.vertical, 2) }
            }
        }
        .padding(16)
        .background(Color.rhCard)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
