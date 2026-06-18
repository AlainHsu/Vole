//
//  MarkdownView.swift
//  Vole
//
//  Created by 杨权 on 8/23/25.
//

import Foundation
import ImageIO
import Kingfisher
import MarkdownView
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

enum LinkAction {
    case mention(username: String)
    case topic(id: Int)
    case node(id: Int)
}

struct VoleMarkdownView: View {
    @State var content: String
    @State private var quickLookURLs: [URL] = []
    @State private var selectedQuickLookURL: URL?
    @State private var isPreparingImagePreview = false

    var onMentionsChanged: (([String]) -> Void)?
    var onLinkAction: ((LinkAction) -> Void)?  // 统一处理链接事件

    var body: some View {
        let (md, mentions) = makeMarkdown(content)
        let imageURLs = MarkdownImageCollector.imageURLs(in: md)
        let renderer = TappableMarkdownImageRenderer(
            imageURLs: imageURLs,
            openImagePreview: openImagePreview
        )

        MarkdownView(md)
            .markdownImageRenderer(renderer, forURLScheme: "http")
            .markdownImageRenderer(renderer, forURLScheme: "https")
            .markdownTableStyle(HorizontalScrollableMarkdownTableStyle())
            .textSelection(.enabled)
            .overlay(alignment: .center) {
                if isPreparingImagePreview {
                    ProgressView()
                        .padding(14)
                        .background(.regularMaterial, in: Circle())
                }
            }
            .quickLookPreview($selectedQuickLookURL, in: quickLookURLs)
            .task(id: content) { @MainActor in
                onMentionsChanged?(mentions)
            }
            .environment(\.openURL, OpenURLAction(handler: handleOpenURL))
    }

    private func makeMarkdown(_ content: String) -> (String, [String]) {
        MarkdownContentFormatter().format(content)
    }

    private func handleOpenURL(_ url: URL) -> OpenURLAction.Result {
        if url.scheme == "mention" {
            let name = url.host ?? url.lastPathComponent
            onLinkAction?(.mention(username: name))
            return .handled
        }

        if let topicId = url.v2exTopicID {
            onLinkAction?(.topic(id: topicId))
            return .handled
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        return .handled
    }

    @MainActor
    private func openImagePreview(
        url: URL,
        image: KFCrossPlatformImage?,
        imageURLs: [URL]
    ) {
        Task {
            do {
                if image == nil {
                    await MainActor.run {
                        isPreparingImagePreview = true
                    }
                }

                let fileURL = try await MarkdownQuickLookImageExporter.fileURL(
                    for: url,
                    image: image
                )

                await MainActor.run {
                    quickLookURLs = [fileURL]
                    selectedQuickLookURL = fileURL
                    isPreparingImagePreview = false
                }

                let urls = imageURLs.isEmpty ? [url] : imageURLs
                let fileURLs = try await MarkdownQuickLookImageExporter.fileURLs(
                    for: urls,
                    preferredImage: image,
                    preferredURL: url
                )

                await MainActor.run {
                    quickLookURLs = fileURLs
                    selectedQuickLookURL = fileURL
                }
            } catch {
                await MainActor.run {
                    isPreparingImagePreview = false
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

private struct TappableMarkdownImageRenderer: MarkdownImageRenderer {
    let imageURLs: [URL]
    var openImagePreview: @MainActor (URL, KFCrossPlatformImage?, [URL]) -> Void

    func makeBody(configuration: Configuration) -> some View {
        TappableMarkdownImage(
            url: configuration.url,
            imageURLs: imageURLs,
            openImagePreview: openImagePreview
        )
    }
}

private struct TappableMarkdownImage: View {
    let url: URL
    let imageURLs: [URL]
    var openImagePreview: @MainActor (URL, KFCrossPlatformImage?, [URL]) -> Void
    @State private var imageSize: CGSize?
    @State private var previewImage: KFCrossPlatformImage?

    private func displaySize(maxWidth: CGFloat) -> CGSize {
        let resolvedSize = resolvedImageSize
        guard resolvedSize.width > 0 else {
            let fallbackWidth = maxWidth > 0 ? maxWidth : 160
            return CGSize(width: fallbackWidth, height: fallbackWidth * 0.75)
        }

        let width = min(resolvedSize.width, maxWidth > 0 ? maxWidth : resolvedSize.width)
        let height = resolvedSize.height * width / resolvedSize.width
        return CGSize(width: width, height: height)
    }

    private var resolvedImageSize: CGSize {
        if let imageSize, imageSize.width > 0, imageSize.height > 0 {
            return imageSize
        }
        if let previewImage, previewImage.size.width > 0, previewImage.size.height > 0 {
            return previewImage.size
        }
        return .zero
    }

    var body: some View {
        GeometryReader { proxy in
            let size = displaySize(maxWidth: proxy.size.width)

            renderedImage
                .frame(
                    width: size.width,
                    height: size.height,
                    alignment: .leading
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture {
                    openImagePreview(url, previewImage, imageURLs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: size.height, alignment: .leading)
        }
        .frame(height: displaySize(maxWidth: UIScreen.main.bounds.width).height)
        .task(id: url) {
            await loadImageSizeIfNeeded()
        }
    }

    @ViewBuilder
    private var renderedImage: some View {
        if url.isGIF {
            animatedImage
        } else {
            staticImage
        }
    }

    private var animatedImage: some View {
        KFAnimatedImage(url)
            .configure { view in
                view.autoPlayAnimatedImage = true
                view.repeatCount = .infinite
                view.framePreloadCount = 3
                view.needsPrescaling = false
                view.contentMode = .scaleAspectFit
            }
            .placeholder {
                imagePlaceholder
            }
            .onSuccess { result in
                handleImageLoaded(result.image, preserveExistingSize: true)
            }
    }

    private var staticImage: some View {
        KFImage(url)
            .placeholder {
                imagePlaceholder
            }
            .onSuccess { result in
                handleImageLoaded(result.image, preserveExistingSize: false)
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private var imagePlaceholder: some View {
        ProgressView()
            .frame(width: 44, height: 44)
    }

    private func handleImageLoaded(
        _ image: KFCrossPlatformImage,
        preserveExistingSize: Bool
    ) {
        previewImage = image
        if preserveExistingSize {
            if imageSize == nil {
                imageSize = image.size
            }
        } else {
            imageSize = image.size
        }
    }

    @MainActor
    private func loadImageSizeIfNeeded() async {
        guard imageSize == nil else { return }
        guard let size = try? await MarkdownImageMetadata.imageSize(for: url) else {
            return
        }
        imageSize = size
    }
}

private struct HorizontalScrollableMarkdownTableStyle: MarkdownTableStyle {
    func makeBody(configuration: Configuration) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 0) {
                configuration.table
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.background.secondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.secondary.opacity(0.28), lineWidth: 1)
                    )
            }
        }
    }
}

private enum MarkdownQuickLookImageExporter {
    static func fileURLs(
        for urls: [URL],
        preferredImage: KFCrossPlatformImage?,
        preferredURL: URL
    ) async throws -> [URL] {
        var exportedURLs: [URL] = []
        var exportedSourceURLs = Set<URL>()

        for url in urls {
            guard exportedSourceURLs.insert(url).inserted else { continue }

            if let fileURL = try? await fileURL(
                for: url,
                image: url == preferredURL ? preferredImage : nil
            ) {
                exportedURLs.append(fileURL)
            }
        }

        return exportedURLs
    }

    static func fileURL(
        for url: URL,
        image: KFCrossPlatformImage?
    ) async throws -> URL {
        let sourceData = try await retrieveOriginalData(for: url)
        let exportFormat = ImageExportFormat.infer(from: sourceData, url: url)
        let fileURL = previewFileURL(for: url, format: exportFormat)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        if exportFormat.preservesAnimation {
            try sourceData.write(to: fileURL, options: .atomic)
            return fileURL
        }

        let exportImage: KFCrossPlatformImage
        if let cachedImage = image {
            exportImage = cachedImage
        } else {
            exportImage = try await retrieveImage(for: url)
        }

        guard let data = exportFormat.data(from: exportImage) else {
            throw CocoaError(.fileWriteUnknown)
        }

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func retrieveImage(for url: URL) async throws -> KFCrossPlatformImage {
        let resource = KF.ImageResource(downloadURL: url)
        return try await KingfisherManager.shared
            .retrieveImage(with: resource)
            .image
    }

    private static func retrieveOriginalData(for url: URL) async throws -> Data {
        try await MarkdownImageDataLoader.data(for: url)
    }

    private static func previewFileURL(for url: URL, format: ImageExportFormat) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoleMarkdownQuickLookImages", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        return directory
            .appendingPathComponent(url.absoluteString.stableFileName)
            .appendingPathExtension(format.fileExtension)
    }
}

private enum MarkdownImageMetadata {
    static func imageSize(for url: URL) async throws -> CGSize {
        let data = try await MarkdownImageDataLoader.data(for: url)

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0,
              height > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return CGSize(width: width, height: height)
    }
}

private enum MarkdownImageDataLoader {
    static func data(for url: URL) async throws -> Data {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
}

private enum ImageExportFormat {
    case gif
    case png
    case jpeg
    case webp
    case bmp
    case tiff

    var fileExtension: String {
        switch self {
        case .gif: return "gif"
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        case .bmp: return "bmp"
        case .tiff: return "tiff"
        }
    }

    var preservesAnimation: Bool {
        switch self {
        case .gif, .webp:
            return true
        default:
            return false
        }
    }

    func data(from image: KFCrossPlatformImage) -> Data? {
        switch self {
        case .gif:
            return image.kf.gifRepresentation()
        case .png:
            return image.kf.pngRepresentation()
        case .jpeg:
            return image.kf.jpegRepresentation(compressionQuality: 1.0)
        case .webp:
            return image.kf.pngRepresentation()
        case .bmp, .tiff:
            return image.kf.pngRepresentation()
        }
    }

    static func infer(from data: Data, url: URL) -> ImageExportFormat {
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let type = CGImageSourceGetType(source) {
            if let utType = UTType(type as String) {
                switch utType {
                case .gif:
                    return .gif
                case .png:
                    return .png
                case .jpeg:
                    return .jpeg
                case .webP:
                    return .webp
                case .bmp:
                    return .bmp
                case .tiff:
                    return .tiff
                default:
                    break
                }
            }
        }

        switch url.pathExtension.lowercased() {
        case "gif":
            return .gif
        case "jpg", "jpeg":
            return .jpeg
        case "webp":
            return .webp
        case "bmp":
            return .bmp
        case "tif", "tiff":
            return .tiff
        default:
            return .png
        }
    }
}

private extension String {
    var stableFileName: String {
        let hash = unicodeScalars.reduce(UInt64(5381)) { result, scalar in
            ((result << 5) &+ result) &+ UInt64(scalar.value)
        }
        return String(format: "%016llx", hash)
    }
}

private extension URL {
    var isGIF: Bool {
        let normalized = absoluteString.lowercased()
        return pathExtension.lowercased() == "gif"
            || normalized.contains(".gif?")
            || normalized.hasSuffix(".gif")
    }

    var v2exTopicID: Int? {
        let host = host?.lowercased()
        guard host == "v2ex.com" || host == "www.v2ex.com" else {
            return nil
        }

        let components = pathComponents
        guard components.count >= 3, components[1] == "t" else {
            return nil
        }

        return Int(components[2])
    }
}

private enum MarkdownImageCollector {
    static func imageURLs(in markdown: String) -> [URL] {
        guard let regex = try? NSRegularExpression(
            pattern: #"!\[[^\]]*\]\(([^)]+)\)"#
        ) else {
            return []
        }

        let nsMarkdown = markdown as NSString
        let matches = regex.matches(
            in: markdown,
            range: NSRange(location: 0, length: nsMarkdown.length)
        )

        return matches.compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }

            let rawURL = nsMarkdown
                .substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: rawURL)
        }
    }
}

private struct MarkdownContentFormatter {
    private let protectedPattern =
        #"(?s)(```.*?```|`[^`\n]*`|!\[[^\]]*\]\([^)]+\)|\[[^\]]+\]\([^)]+\))"#
    private let mentionPattern =
        #"(?<![\p{L}0-9_])@([\p{L}0-9_]+)(?![\p{L}0-9_])"#
    private let urlPattern =
        #"https?://[^\s<>()\[\]{}]+"#
    private let imageURLPattern =
        #"(?i)^https?://\S+\.(?:png|jpg|jpeg|gif|webp|bmp|tiff)(?:\?\S*)?$"#

    func format(_ content: String) -> (markdown: String, mentions: [String]) {
        var mentions: [String] = []
        let markdown = transformUnprotectedSegments(in: content) {
            segment in
            processTextSegment(segment, mentions: &mentions)
        }
        return (markdown, mentions)
    }

    private func transformUnprotectedSegments(
        in content: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: protectedPattern)
        else {
            return transform(content)
        }

        let nsContent = content as NSString
        let matches = regex.matches(
            in: content,
            range: NSRange(location: 0, length: nsContent.length)
        )
        var result = ""
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let range = NSRange(
                    location: cursor,
                    length: match.range.location - cursor
                )
                result += transform(nsContent.substring(with: range))
            }

            result += nsContent.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }

        if cursor < nsContent.length {
            result += transform(nsContent.substring(from: cursor))
        }

        return result
    }

    private func processTextSegment(
        _ text: String,
        mentions: inout [String]
    ) -> String {
        guard let urlRegex = try? NSRegularExpression(pattern: urlPattern)
        else {
            return processMentions(in: text, mentions: &mentions)
        }

        let nsText = text as NSString
        let matches = urlRegex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )
        var result = ""
        var cursor = 0

        for match in matches {
            if match.range.location > cursor {
                let range = NSRange(
                    location: cursor,
                    length: match.range.location - cursor
                )
                result += processMentions(
                    in: nsText.substring(with: range),
                    mentions: &mentions
                )
            }

            let rawURL = nsText.substring(with: match.range)
            let (url, suffix) = trimTrailingURLPunctuation(rawURL)
            result += markdownLink(for: url) + suffix
            cursor = match.range.location + match.range.length
        }

        if cursor < nsText.length {
            result += processMentions(
                in: nsText.substring(from: cursor),
                mentions: &mentions
            )
        }

        return result
    }

    private func processMentions(
        in text: String,
        mentions: inout [String]
    ) -> String {
        replaceMatches(
            in: text,
            pattern: mentionPattern
        ) { _, match in
            guard let nameRange = Range(match.range(at: 1), in: text)
            else {
                return nil
            }

            let name = String(text[nameRange])
            mentions.append(name)
            let encoded = name.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ) ?? name
            return "[@\(name)](mention://\(encoded))"
        }
    }

    private func replaceMatches(
        in text: String,
        pattern: String,
        replacement: (String, NSTextCheckingResult) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var result = text
        let nsText = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        )

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else {
                continue
            }
            let matchText = String(result[range])
            guard let replacement = replacement(matchText, match) else {
                continue
            }
            result.replaceSubrange(range, with: replacement)
        }

        return result
    }

    private func markdownLink(for url: String) -> String {
        if url.range(of: imageURLPattern, options: .regularExpression) != nil {
            return "![image](\(url))"
        }
        return "[\(url)](\(url))"
    }

    private func trimTrailingURLPunctuation(_ url: String)
        -> (url: String, suffix: String)
    {
        var trimmed = url
        var suffix = ""
        while let last = trimmed.last, ".,;:!?".contains(last) {
            suffix.insert(last, at: suffix.startIndex)
            trimmed.removeLast()
        }
        return (trimmed, suffix)
    }

}

#Preview {

    ScrollView {
        let markdownString = """
            帮 OP 重发图片。    
                
            ![image](https://i.imgur.com/61pfQZT.png)    
            ![image](https://i.imgur.com/4WJyF6w.png)    
            ![image](https://i.imgur.com/KEBNsVW.png)    
            ![image](https://i.imgur.com/yVTQO66.png)    
            ![image](https://i.imgur.com/Moyp0xD.png)    
            ![image](https://i.imgur.com/qY9MksK.png)    
            ![image](https://i.imgur.com/v0XnJTS.png)    
            ![image](https://i.imgur.com/zy09Dt6.png)    
            ![image](https://i.imgur.com/lDFqr3j.png)    
            ![image](https://i.imgur.com/0uptnWx.png)
            """

        VoleMarkdownView(content: markdownString)
    }
}
