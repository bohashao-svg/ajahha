import UIKit
import SwiftUI

// MARK: - AlamofireImage Bridge
// Mirrors AlamofireImage's ImageDownloader + ImageCache API.
// RHImageCache and RHRemoteImage are defined in Services/RHImageCache.swift.
// This file adds: RHImageDownloader, UIImageView extension, RHImageFilter.

// MARK: - Image Downloader (mirrors AlamofireImage's ImageDownloader)

public final class RHImageDownloader {
    public static let shared = RHImageDownloader()

    private let session: URLSession
    private var activeTasks: [String: URLSessionDataTask] = [:]
    private let lock = NSLock()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024,
                                   diskCapacity: 150 * 1024 * 1024)
        session = URLSession(configuration: config)
    }

    @discardableResult
    public func download(url: String,
                         filter: ((UIImage) -> UIImage)? = nil,
                         completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        if let cached = RHImageCache.shared.image(for: url) {
            completion(cached)
            return nil
        }
        guard let urlObj = URL(string: url) else { completion(nil); return nil }

        lock.lock()
        if activeTasks[url] != nil { lock.unlock(); return nil }

        let task = session.dataTask(with: urlObj) { [weak self] data, _, _ in
            defer {
                self?.lock.lock()
                self?.activeTasks.removeValue(forKey: url)
                self?.lock.unlock()
            }
            guard let data, var image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if let filter { image = filter(image) }
            RHImageCache.shared.store(image, for: url)
            DispatchQueue.main.async { completion(image) }
        }
        activeTasks[url] = task
        lock.unlock()
        task.resume()
        return task
    }

    public func cancel(url: String) {
        lock.lock()
        activeTasks[url]?.cancel()
        activeTasks.removeValue(forKey: url)
        lock.unlock()
    }
}

// MARK: - UIImageView Extension (mirrors AlamofireImage's af.setImage)

private var _rhUrlKey = "RHImageDownloaderURLKey"

extension UIImageView {
    func rh_setImage(withURL urlString: String,
                     placeholder: UIImage? = nil,
                     filter: ((UIImage) -> UIImage)? = nil,
                     completion: ((UIImage?) -> Void)? = nil) {
        if let prev = objc_getAssociatedObject(self, &_rhUrlKey) as? String, prev != urlString {
            RHImageDownloader.shared.cancel(url: prev)
        }
        objc_setAssociatedObject(self, &_rhUrlKey, urlString, .OBJC_ASSOCIATION_RETAIN_NONATOMICALLY)

        if let cached = RHImageCache.shared.image(for: urlString) {
            image = cached
            completion?(cached)
            return
        }
        image = placeholder
        RHImageDownloader.shared.download(url: urlString, filter: filter) { [weak self] img in
            guard let self,
                  objc_getAssociatedObject(self, &_rhUrlKey) as? String == urlString else { return }
            UIView.transition(with: self, duration: 0.22, options: .transitionCrossDissolve) {
                self.image = img
            }
            completion?(img)
        }
    }
}

// MARK: - Image Filter Helpers (mirrors AlamofireImage's ImageFilter)

public struct RHImageFilter {
    public static func circle(_ image: UIImage) -> UIImage {
        let size = min(image.size.width, image.size.height)
        let rect = CGRect(x: (image.size.width - size) / 2,
                          y: (image.size.height - size) / 2,
                          width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, image.scale)
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: size, height: size))).addClip()
        image.draw(at: CGPoint(x: -rect.origin.x, y: -rect.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result ?? image
    }

    public static func blur(radius: CGFloat) -> (UIImage) -> UIImage {
        return { image in
            guard let ciImage = CIImage(image: image) else { return image }
            let filter = CIFilter(name: "CIGaussianBlur")!
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(radius, forKey: kCIInputRadiusKey)
            guard let output = filter.outputImage,
                  let cgImage = CIContext().createCGImage(output, from: ciImage.extent) else { return image }
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
    }
}
