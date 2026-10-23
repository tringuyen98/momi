import Foundation
import CryptoKit
import CommonCrypto
import Security

public struct OCRLine: Codable, Equatable, Sendable {
    public var text: String
    public var confidence: Float
    public var page: Int
    public init(text: String, confidence: Float, page: Int = 0) { self.text = text; self.confidence = confidence; self.page = page }
}
public struct VaccineDraft: Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var name = ""
    public var vaccineID: UUID?
    public var category: VaccineCategory = .other
    public var product = ""
    public var number = ""
    public var injectedDateText = ""
    public var nextDateText = ""
    public var place = ""
    public var lot = ""
    public var rawText = ""
    public var confirmed = false
    public init() {}
}
public enum VaccineDocumentParser {
    /// Conservative extraction. Unlabelled dates remain in raw text for review.
    public static func parse(_ lines: [OCRLine]) -> VaccineDraft {
        var draft = VaccineDraft()
        draft.rawText = lines.map { "[Trang \($0.page + 1)] \($0.text)" }.joined(separator: "\n")
        let known = ["viêm gan b", "cúm", "rubella", "thủy đậu", "uốn ván", "sởi", "hpv"]
        for line in lines {
            let text = line.text
            let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            if draft.name.isEmpty, let name = known.first(where: { normalized.contains($0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))) }) { draft.name = name.prefix(1).uppercased() + name.dropFirst() }
            let dates = matches(#"\b\d{1,2}[/.-]\d{1,2}[/.-]\d{4}\b"#, text)
            if normalized.contains("hen") || normalized.contains("tiep theo") {
                if let value = dates.first { draft.nextDateText = value }
            } else if normalized.contains("ngay tiem"), let value = dates.first { draft.injectedDateText = value }
            if normalized.contains("so lo"), let colon = text.firstIndex(of: ":") { draft.lot = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespaces) }
        }
        return draft
    }
    private static func matches(_ pattern: String, _ text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }
}

public struct BackupPayload: Codable, Sendable {
    public var snapshot: Snapshot
    public var files: [String: Data]
    public var createdAt: Date
    public init(snapshot: Snapshot, files: [String: Data]) { self.snapshot = snapshot; self.files = files; createdAt = Date() }
    public func validate() throws {
        guard snapshot.schemaVersion == 1 else { throw ValidationError.message("Phiên bản backup chưa được hỗ trợ.") }
        guard snapshot.profile.cycleLength.map({ (15...60).contains($0) }) ?? true,
              snapshot.profile.periodLength.map({ (1...14).contains($0) }) ?? true,
              snapshot.vaccines.allSatisfy({ $0.plannedDoseCount.map { (1...20).contains($0) } ?? true }) else {
            throw ValidationError.message("Thiết lập chu kỳ hoặc số mũi vaccine trong backup không hợp lệ.")
        }
        func unique<T: Identifiable>(_ values: [T]) -> Bool where T.ID: Hashable { Set(values.map(\.id)).count == values.count }
        guard unique(snapshot.tasks), unique(snapshot.supplements), unique(snapshot.intakes), unique(snapshot.appointments),
              unique(snapshot.vaccines), unique(snapshot.vaccinations), unique(snapshot.attachments), unique(snapshot.records),
              unique(snapshot.journal), unique(snapshot.dailyLogs), unique(snapshot.meals), unique(snapshot.ultrasounds) else { throw ValidationError.message("Backup có bản ghi trùng.") }
        let days = snapshot.dailyLogs.map(\.day) + snapshot.vaccinations.map(\.day) + snapshot.journal.map(\.day) + snapshot.records.map(\.day) + snapshot.meals.map(\.day) + snapshot.intakes.map(\.day) + snapshot.tasks.compactMap(\.dueDay) + snapshot.ultrasounds.map(\.day)
        guard days.allSatisfy({ Day.date($0) != nil }), snapshot.profile.dueDate.map({ Day.date($0) != nil }) ?? true else { throw ValidationError.message("Ngày trong backup không hợp lệ.") }
        guard snapshot.ultrasounds.allSatisfy({ (0...42).contains($0.week) && !$0.attachmentIDs.isEmpty }) else { throw ValidationError.message("Tuần hoặc ảnh siêu âm trong backup không hợp lệ.") }
        for supplement in snapshot.supplements {
            guard unique(supplement.schedules), Set(supplement.schedules.map(\.effectiveFrom)).count == supplement.schedules.count else { throw ValidationError.message("Lịch uống bị trùng phiên bản.") }
            for plan in supplement.schedules {
                guard Day.date(plan.effectiveFrom) != nil,
                      plan.effectiveThrough.map({ Day.date($0) != nil && $0 >= plan.effectiveFrom }) ?? true,
                      unique(plan.slots), plan.slots.allSatisfy({ (0...23).contains($0.hour) && (0...59).contains($0.minute) }),
                      !plan.weekdays.isEmpty, plan.weekdays.allSatisfy({ (1...7).contains($0) }) else { throw ValidationError.message("Lịch uống trong backup không hợp lệ.") }
            }
        }
        let expected = Set(snapshot.attachments.map(\.filename))
        guard expected == Set(files.keys) else { throw ValidationError.message("Backup thiếu hoặc thừa file đính kèm.") }
        for name in files.keys {
            guard !name.contains("/"), !name.contains("\\"), !name.hasPrefix("."), !name.isEmpty else { throw ValidationError.message("Tên file trong backup không hợp lệ.") }
        }
        guard Set(snapshot.intakes.map(\.id)).count == snapshot.intakes.count,
              Set(snapshot.attachments.map(\.id)).count == snapshot.attachments.count else { throw ValidationError.message("Backup có bản ghi trùng.") }
        let attachmentIDs = Set(snapshot.attachments.map(\.id))
        let referenced = snapshot.records.flatMap(\.attachmentIDs) + snapshot.journal.flatMap(\.attachmentIDs) + snapshot.vaccinations.flatMap(\.attachmentIDs) + snapshot.supplements.flatMap(\.attachmentIDs) + snapshot.ultrasounds.flatMap(\.attachmentIDs)
        guard Set(referenced).isSubset(of: attachmentIDs),
              Set(snapshot.vaccinations.map(\.vaccineID)).isSubset(of: Set(snapshot.vaccines.map(\.id))) else { throw ValidationError.message("Liên kết trong backup bị thiếu.") }
    }
}
public enum BackupCipher {
    private struct Envelope: Codable {
        var version: Int
        var rounds: UInt32
        var salt: Data
        var ciphertext: Data
    }
    public static func encrypt(_ payload: BackupPayload, password: String) throws -> Data {
        guard password.count >= 10 else { throw ValidationError.message("Mật khẩu backup cần ít nhất 10 ký tự.") }
        try payload.validate()
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw ValidationError.message("Không tạo được khóa bảo vệ backup.") }
        let salt = Data(bytes)
        let key = try derive(password, salt: salt, rounds: 210_000)
        let sealed = try AES.GCM.seal(JSONEncoder().encode(payload), using: key)
        return try JSONEncoder().encode(Envelope(version: 1, rounds: 210_000, salt: salt, ciphertext: sealed.combined!))
    }
    public static func decrypt(_ data: Data, password: String) throws -> BackupPayload {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard envelope.version == 1, envelope.rounds == 210_000, envelope.salt.count == 16 else { throw ValidationError.message("Định dạng backup không được hỗ trợ.") }
        let key = try derive(password, salt: envelope.salt, rounds: envelope.rounds)
        let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.ciphertext), using: key)
        let payload = try JSONDecoder().decode(BackupPayload.self, from: plain)
        try payload.validate()
        return payload
    }
    private static func derive(_ password: String, salt: Data, rounds: UInt32) throws -> SymmetricKey {
        let pass = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = pass.withUnsafeBytes { p in
            salt.withUnsafeBytes { s in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), p.baseAddress!.assumingMemoryBound(to: Int8.self), pass.count,
                    s.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds, &derived, derived.count)
            }
        }
        guard status == kCCSuccess else { throw ValidationError.message("Không tạo được khóa backup.") }
        return SymmetricKey(data: Data(derived))
    }
}
