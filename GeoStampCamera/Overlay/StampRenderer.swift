import UIKit
import AVFoundation
import QuartzCore

/// Рисует штамп «время + локация» на фото и видео.
enum StampRenderer {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()

    static func lines(date: Date, locationLines: [String]) -> [String] {
        [dateFormatter.string(from: date)] + locationLines
    }

    // MARK: - Photo

    static func stamp(image: UIImage, lines: [String]) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            let fontSize = max(size.width, size.height) * 0.022
            drawText(lines.joined(separator: "\n"), in: size, fontSize: fontSize)
        }
    }

    private static func drawText(_ text: String, in size: CGSize, fontSize: CGFloat) {
        let attrs = textAttributes(fontSize: fontSize)
        let padding = fontSize * 0.8
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: size.width - padding * 4, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        let box = CGRect(x: padding,
                         y: size.height - bounds.height - padding * 3,
                         width: bounds.width + padding * 2,
                         height: bounds.height + padding * 2)
        UIColor.black.withAlphaComponent(0.45).setFill()
        UIBezierPath(roundedRect: box, cornerRadius: padding / 2).fill()
        (text as NSString).draw(
            in: box.insetBy(dx: padding, dy: padding), withAttributes: attrs)
    }

    private static func textAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
    }

    // MARK: - Video

    /// Экспортирует копию видео с наложенным штампом. Время на видео идёт «живым»
    /// счётчиком: стартовое время записи + текущая позиция в ролике.
    static func stampVideo(at inputURL: URL, startDate: Date, locationLines: [String]) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "StampRenderer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Нет видеодорожки"])
        }
        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)
        let rendered = naturalSize.applying(transform)
        let renderSize = CGSize(width: abs(rendered.width), height: abs(rendered.height))

        let composition = AVMutableVideoComposition(propertiesOf: asset)
        composition.renderSize = renderSize

        // Слои: видео + текстовый оверлей.
        let parent = CALayer()
        let videoLayer = CALayer()
        parent.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)

        let fontSize = max(renderSize.width, renderSize.height) * 0.022
        let padding = fontSize * 0.8
        let lineCount = CGFloat(1 + locationLines.count)
        let boxHeight = fontSize * 1.25 * lineCount + padding * 2
        let box = CALayer()
        box.frame = CGRect(x: padding, y: padding * 2,   // CoreAnimation: начало координат снизу
                           width: renderSize.width - padding * 2, height: boxHeight)
        box.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
        box.cornerRadius = padding / 2
        parent.addSublayer(box)

        // Статичная часть (локация).
        let locLayer = makeTextLayer(locationLines.joined(separator: "\n"), fontSize: fontSize)
        locLayer.frame = CGRect(x: padding, y: padding,
                                width: box.bounds.width - padding * 2,
                                height: fontSize * 1.25 * CGFloat(locationLines.count))
        box.addSublayer(locLayer)

        // Время: по одному слою на каждую секунду, показываем через keyframe-анимацию opacity.
        let seconds = Int(ceil(duration.seconds))
        let timeFrame = CGRect(x: padding, y: locLayer.frame.maxY,
                               width: locLayer.frame.width, height: fontSize * 1.25)
        for s in 0..<max(seconds, 1) {
            let t = makeTextLayer(dateFormatter.string(from: startDate.addingTimeInterval(TimeInterval(s))),
                                  fontSize: fontSize)
            t.frame = timeFrame
            t.opacity = 0
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 1
            anim.toValue = 1
            anim.beginTime = s == 0 ? AVCoreAnimationBeginTimeAtZero : CFTimeInterval(s)
            anim.duration = 1
            anim.isRemovedOnCompletion = false
            t.add(anim, forKey: "show")
            box.addSublayer(t)
        }

        composition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parent)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "StampRenderer", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Не удалось создать экспорт"])
        }
        export.outputURL = outputURL
        export.outputFileType = .mov
        export.videoComposition = composition
        await export.export()
        if let error = export.error { throw error }
        return outputURL
    }

    private static func makeTextLayer(_ text: String, fontSize: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = NSAttributedString(string: text, attributes: textAttributes(fontSize: fontSize))
        layer.contentsScale = 2
        layer.isWrapped = true
        layer.alignmentMode = .left
        return layer
    }
}
