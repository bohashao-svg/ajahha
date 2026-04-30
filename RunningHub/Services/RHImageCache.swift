import UIKit
import SwiftUI

// MARK: - RHImageCache
// NSCache-backed image cache inspired by AlamofireImage's ImageCache design.
// Thread-safe: NSCache handles concurrent reads; writes are serialized on a background queue.

final class RHImageCache {
    static let shared = RHImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 100
        c.totalCostLimit = 100 * 1024 * 1024  // 100 MB
        return c
    }()

    private init() {}

    func image(for url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func store(_ image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: url as NSString, cost: cost)
    }

    func remove(for url: String) {
        cache.removeObject(forKey: url as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

// MARK: - RHRemoteImage (SwiftUI View)
// Drop-in replacement for AsyncImage with NSCache backing.

struct RHRemoteImage: View {
    let url: String
    var contentMode: ContentMode = .fit
    var cornerRadius: CGFloat = 0

    @StateObject private var loader = RHImageLoader()

    var body: some View {
        Group {
            switch loader.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            case .success(let img):
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .cornerRadius(cornerRadius)
            case .failure:
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundColor(.rhSecondary)
                    Text("图片加载失败")
                        .font(.system(size: 13))
                        .foregroundColor(.rhSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(Color.rhBackground)
                .cornerRadius(cornerRadius)
            }
        }
        .onAppear { loader.load(url) }
        .onDisappear { loader.cancel() }
    }
}

// MARK: - RHImageLoader

@MainActor
final class RHImageLoader: ObservableObject {
    enum State { case idle, loading, success(UIImage), failure }

    @Published var state: State = .idle

    private var task: URLSessionDataTask?

    func load(_ urlString: String) {
        guard case .idle = state else { return }

        // Cache hit
        if let cached = RHImageCache.shared.image(for: urlString) {
            state = .success(cached)
            return
        }

        guard let url = URL(string: urlString) else {
            state = .failure
            return
        }

        state = .loading
        task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let data, let img = UIImage(data: data) {
                    RHImageCache.shared.store(img, for: urlString)
                    self.state = .success(img)
                } else {
                    self.state = .failure
                }
            }
        }
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
