import Foundation
import Vision
import PDFKit
import ImageIO
import MomiCore

struct OCRService: Sendable {
    func recognize(data: Data, isPDF: Bool) async throws -> [OCRLine] {
        try await Task.detached(priority: .userInitiated) {
            var images: [CGImage] = []
            if isPDF {
                guard let pdf = PDFDocument(data: data), pdf.pageCount <= 20 else { throw ValidationError.message("Chọn PDF hợp lệ, tối đa 20 trang mỗi lần.") }
                var allText: [OCRLine] = []
                for pageIndex in 0..<pdf.pageCount {
                    try Task.checkCancellation()
                    guard let page = pdf.page(at: pageIndex) else { continue }
                    if let text = page.string, text.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 {
                        allText += text.components(separatedBy: .newlines).filter { !$0.isEmpty }.map { OCRLine(text: $0, confidence: 1, page: pageIndex) }
                        continue
                    }
                    let bounds = page.bounds(for: .mediaBox)
                    guard bounds.width > 0, bounds.height > 0 else { continue }
                    let scale = min(2, 2200 / max(bounds.width, bounds.height))
                    guard let context = CGContext(data: nil, width: Int(bounds.width * scale), height: Int(bounds.height * scale), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
                    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: bounds.width * scale, height: bounds.height * scale))
                    context.scaleBy(x: scale, y: scale); context.translateBy(x: -bounds.minX, y: -bounds.minY)
                    page.draw(with: .mediaBox, to: context)
                    if let image = context.makeImage() { allText += try Self.recognizeImage(image, page: pageIndex) }
                }
                guard !allText.isEmpty else { throw ValidationError.message("Chưa đọc được chữ. Thử ảnh rõ hơn hoặc nhập tay.") }
                return allText
            }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2600] as CFDictionary) else { throw ValidationError.message("Không đọc được định dạng ảnh này.") }
            images.append(image)
            let lines = try Self.recognizeImage(images[0], page: 0)
            guard !lines.isEmpty else { throw ValidationError.message("Chưa đọc được chữ. Thử chụp rõ hơn hoặc nhập tay.") }
            return lines
        }.value
    }
    private static func recognizeImage(_ image: CGImage, page: Int) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        let selected = supported.filter { $0.hasPrefix("vi") || $0 == "en-US" }
        if !selected.isEmpty { request.recognitionLanguages = selected }
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { result in
            result.topCandidates(1).first.map { OCRLine(text: $0.string, confidence: $0.confidence, page: page) }
        }
    }
}
