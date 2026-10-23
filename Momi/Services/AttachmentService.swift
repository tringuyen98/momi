import Foundation
import MomiCore

struct AttachmentService: Sendable {
    let directory: URL
    init() throws {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        directory = base.appendingPathComponent("MomiAttachments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func url(_ attachment: Attachment) -> URL { directory.appendingPathComponent(attachment.filename) }
    func save(_ data: Data, name: String, extension ext: String) throws -> Attachment {
        guard data.count <= 30 * 1024 * 1024 else { throw ValidationError.message("File quá lớn. Hãy chọn file dưới 30 MB.") }
        let safeExtension = ["jpg", "jpeg", "png", "pdf", "heic"].contains(ext.lowercased()) ? ext.lowercased() : "jpg"
        let attachment = Attachment(filename: UUID().uuidString + "." + safeExtension, displayName: name)
        try data.write(to: url(attachment), options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url(attachment).path)
        #endif
        return attachment
    }
    func files(for snapshot: Snapshot) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for a in snapshot.attachments { result[a.filename] = try Data(contentsOf: url(a)) }
        return result
    }
    /// Copy into fresh names first. The old files remain valid if committing the database fails.
    func stageRestore(_ payload: BackupPayload) throws -> Snapshot {
        try payload.validate()
        var snapshot = payload.snapshot
        var created: [URL] = []
        do {
            for i in snapshot.attachments.indices {
                let old = snapshot.attachments[i]
                let file = try save(payload.files[old.filename]!, name: old.displayName, extension: URL(fileURLWithPath: old.filename).pathExtension)
                created.append(url(file)); snapshot.attachments[i].filename = file.filename
            }
            return snapshot
        } catch {
            for url in created { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }
    func cleanup(keeping snapshot: Snapshot) {
        let names = Set(snapshot.attachments.map(\.filename))
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where !names.contains(file.lastPathComponent) { try? FileManager.default.removeItem(at: file) }
    }
}
