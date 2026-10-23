import SwiftUI
import MomiCore
#if os(iOS)
import VisionKit
import UIKit

struct DocumentScanner: UIViewControllerRepresentable {
    var onComplete: (Result<[Data], Error>) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController(); scanner.delegate = context.coordinator; return scanner
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onComplete: (Result<[Data], Error>) -> Void
        init(onComplete: @escaping (Result<[Data], Error>) -> Void) { self.onComplete = onComplete }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount <= 20 else { onComplete(.failure(ValidationError.message("Tối đa 20 trang mỗi lần."))); return }
            var images: [Data] = []
            for i in 0..<scan.pageCount { if let data = scan.imageOfPage(at: i).jpegData(compressionQuality: 0.85) { images.append(data) } }
            onComplete(.success(images))
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onComplete(.success([])) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onComplete(.failure(error)) }
    }
}
#endif
