import SwiftUI
import UIKit

// MARK: - OutputCardView
// SwiftUI bridge for Cards library's CardHighlight.
// Liquid glass reskin: deep space palette, glass border, glow shadow.

struct OutputCardView: UIViewRepresentable {
    let imageURL: String
    let title: String
    var subtitle: String = ""
    var onTap: (() -> Void)?

    func makeUIView(context: Context) -> CardHighlight {
        let card = CardHighlight(frame: .zero)
        card.title = title
        card.itemTitle = subtitle
        card.cardRadius = 20
        card.shadowBlur = 24
        card.shadowOpacity = 0.35
        card.shadowColor = UIColor(hex: "#6C8EFF")
        card.textColor = .white
        card.backgroundImage = UIImage(systemName: "photo")

        // Liquid glass overlay on card
        applyGlassStyle(to: card)

        // Load image via RHImageDownloader (AlamofireImage bridge)
        RHImageDownloader.shared.download(url: imageURL) { img in
            guard let img else { return }
            DispatchQueue.main.async { card.backgroundImage = img }
        }

        card.delegate = context.coordinator
        return card
    }

    func updateUIView(_ uiView: CardHighlight, context: Context) {
        uiView.title = title
        uiView.itemTitle = subtitle
        if let cached = RHImageCache.shared.image(for: imageURL) {
            uiView.backgroundImage = cached
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    private func applyGlassStyle(to card: CardHighlight) {
        card.backgroundColor = UIColor(hex: "#111827").withAlphaComponent(0.72)
        // Glass border
        card.layer.borderColor = UIColor(white: 1, alpha: 0.14).cgColor
        card.layer.borderWidth = 1
        // Inner gradient overlay
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(white: 1, alpha: 0.09).cgColor,
            UIColor(white: 1, alpha: 0.02).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 220, height: 280)
        card.layer.insertSublayer(gradientLayer, at: 0)
    }

    final class Coordinator: NSObject, CardDelegate {
        var onTap: (() -> Void)?
        init(onTap: (() -> Void)?) { self.onTap = onTap }
        func cardDidTapInside(card: Card) { onTap?() }
    }
}
