import SwiftUI
#if canImport(UIKit)
import UIKit
import ImageIO
#endif

/// A lightweight SwiftUI wrapper that plays a bundled GIF by name (without extra dependencies).
/// Place the GIF inside the asset catalog (.xcassets) and pass its name without extension.
#if canImport(UIKit)
struct AnimatedGifView: UIViewRepresentable {
    class Coordinator {
        var animated: UIImage?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    let name: String
    @Binding var isPlaying: Bool
    let contentMode: UIView.ContentMode

    init(name: String, isPlaying: Binding<Bool>, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.name = name
        self._isPlaying = isPlaying
        self.contentMode = contentMode
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        let animated = AnimatedGifView.animatedImage(named: name)
        context.coordinator.animated = animated
        imageView.image = isPlaying ? animated : animated?.images?.first
        if isPlaying {
            imageView.startAnimating()
        }
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if isPlaying {
            if !uiView.isAnimating {
                uiView.animationImages = context.coordinator.animated?.images
                uiView.animationDuration = context.coordinator.animated?.duration ?? 0
                uiView.startAnimating()
            }
        } else {
            if uiView.isAnimating {
                uiView.stopAnimating()
            }
            uiView.image = context.coordinator.animated?.images?.first
        }
    }

    // MARK: - Helper
    private static func animatedImage(named name: String) -> UIImage? {
        guard
            let url = Bundle.main.url(forResource: name, withExtension: "gif"),
            let data = try? Data(contentsOf: url),
            let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            return nil
        }

        let count = CGImageSourceGetCount(source)
        var images: [UIImage] = []
        var duration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            // Get frame duration
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gifInfo = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
               let delay = gifInfo[kCGImagePropertyGIFDelayTime] as? Double {
                duration += delay
            }
        }

        // Fallback duration if metadata failed
        if duration == 0 { duration = Double(count) * 0.1 }

        return UIImage.animatedImage(with: images, duration: duration)
    }
}
#else
/// Placeholder for non-UIKit platforms
struct AnimatedGifView: View {
    var name: String
    var body: some View { EmptyView() }
}
#endif
