import Foundation
import MomiCore
#if os(iOS)
import UIKit

@MainActor enum PDFExport {
    static func summary(_ snapshot: Snapshot) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 44
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.black]
            for paragraph in DataExport.healthSummary(snapshot, now: Date()) {
                var remainder = paragraph
                while !remainder.isEmpty {
                    let end = remainder.index(remainder.startIndex, offsetBy: min(800, remainder.count))
                    let part = String(remainder[..<end])
                    remainder = String(remainder[end...])
                    let bounds = (part as NSString).boundingRect(with: CGSize(width: 507, height: 700), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                    let height = ceil(bounds.height) + 10
                    if y + height > 790 { context.beginPage(); y = 44 }
                    (part as NSString).draw(in: CGRect(x: 44, y: y, width: 507, height: height), withAttributes: attributes)
                    y += height
                }
            }
        }
    }
}
#endif
