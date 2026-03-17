import UIKit

enum ImageResizer {
    static func resize(image: UIImage, targetSize: CGSize) -> UIImage? {
        let widthRatio = targetSize.width / image.size.width
        let heightRatio = targetSize.height / image.size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
