import SwiftUI
import ImageIO
import CryptoKit

// Decode a display-sized bitmap once on the cache actor. View body evaluation
// and the first render both avoid JPEG decompression on the main thread.
private actor PhotoCache {
    static let shared = PhotoCache()
    private let cache = NSCache<NSString, UIImage>()
    init() { cache.totalCostLimit = 32 * 1024 * 1024; cache.countLimit = 80 }
    func image(data: Data, maxPixelSize: Int) -> UIImage? {
        let key = "\(SHA256.hash(data: data))-\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: bitmap)
        cache.setObject(image, forKey: key, cost: bitmap.bytesPerRow * bitmap.height)
        return image
    }
}

struct PreparedPhoto: View {
    let data: Data
    let maxPixelSize: Int
    let contentMode: ContentMode
    @State private var loaded: Loaded?
    private struct Request: Equatable { let data: Data; let maxPixelSize: Int }
    private struct Loaded { let request: Request; let image: UIImage? }
    var body: some View {
        let request = Request(data: data, maxPixelSize: maxPixelSize)
        Group {
            if let loaded, loaded.request == request, let image = loaded.image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else { Rectangle().fill(SanjuTheme.surface) }
        }
        .task(id: request) {
            let image = await PhotoCache.shared.image(data: request.data, maxPixelSize: request.maxPixelSize)
            guard !Task.isCancelled else { return }
            loaded = Loaded(request: request, image: image)
        }
    }
}

enum PhotoProcessor {
    static func prepare(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1280,
                kCGImageSourceShouldCacheImmediately: true,
              ] as CFDictionary) else { throw PhotoError.unreadable }
        // A freshly encoded bitmap contains no source EXIF/GPS metadata.
        var image = UIImage(cgImage: thumbnail)
        for _ in 0..<4 {
            for quality in [0.85, 0.65, 0.45, 0.3] {
                if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= 500 * 1024 { return jpeg }
            }
            let size = CGSize(width: image.size.width * 0.75, height: image.size.height * 0.75)
            image = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        }
        throw PhotoError.unreadable
    }
    enum PhotoError: LocalizedError {
        case unreadable
        var errorDescription: String? { "这张照片没能读取，请重新选择，也可以只写画面。" }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var completion: (Data?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (Data?) -> Void
        init(completion: @escaping (Data?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completion((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.95))
        }
    }
}
