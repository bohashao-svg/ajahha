import SwiftUI
import UIKit

// MARK: - OutputCardView
// SwiftUI bridge for Cards library's CardHighlight.
// Used in TaskDetailView to display generated output images as interactive cards.

struct OutputCardView: UIViewRepresentable {
    let imageURL: String
    let title: String
    var subtitle: String = ""
    var onTap: (() -> Void)?

    func makeUIView(context: Context) -> CardHighlight {
        let card = CardHighlight(frame: .zero)
        card.title = title
        card.itemTitle = subtitle
        card.cardRadius = 18
        card.shadowBlur = 10
        card.shadowOpacity = 0.15
        card.shadowColor = UIColor(hex: "#C8392B")
        card.textColor = .white
        card.backgroundImage = UIImage(systemName: "photo")  // placeholder

        // Load image asynchronously
        if let url = URL(string: imageURL) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data, let img = UIImage(data: data) else { return }
                RHImageCache.shared.store(img, for: imageURL)
                DispatchQueue.main.async { card.backgroundImage = img }
            }.resume()
        }

        // Tap handler via delegate
        card.delegate = context.coordinator
        return card
    }

    func updateUIView(_ uiView: CardHighlight, context: Context) {
        uiView.title = title
        uiView.itemTitle = subtitle
        // Update image if cached
        if let cached = RHImageCache.shared.image(for: imageURL) {
            uiView.backgroundImage = cached
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject, CardDelegate {
        var onTap: (() -> Void)?
        init(onTap: (() -> Void)?) { self.onTap = onTap }

        func cardDidTapInside(card: Card) { onTap?() }
    }
}
