import Foundation

public struct GestationalAge: Equatable, Sendable {
    public var days: Int
    public var week: Int { days / 7 }
    public var remainder: Int { days % 7 }
}
public enum PregnancyTimeline {
    public static let weeks = Array(0...42)
    public static func age(dueDate: String?, on day: String, calendar: Calendar = .current) -> GestationalAge? {
        guard let dueDate, let due = Day.date(dueDate, calendar: calendar), let today = Day.date(day, calendar: calendar),
              let untilDue = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: due)).day else { return nil }
        let days = 280 - untilDue
        guard (0...300).contains(days) else { return nil }
        return GestationalAge(days: days)
    }
    public static func entries(_ snapshot: Snapshot, week: Int) -> [UltrasoundEntry] {
        snapshot.ultrasounds.filter { $0.week == week }.sorted { ($0.day, $0.id.uuidString) > ($1.day, $1.id.uuidString) }
    }
    public static func save(_ entry: UltrasoundEntry, files: [Attachment], in snapshot: inout Snapshot) throws {
        guard weeks.contains(entry.week), Day.date(entry.day) != nil, !entry.attachmentIDs.isEmpty else { throw ValidationError.message("Chọn tuần, ngày và ít nhất một ảnh hoặc PDF siêu âm.") }
        let known = Set(snapshot.attachments.map(\.id) + files.map(\.id))
        guard Set(entry.attachmentIDs).isSubset(of: known) else { throw ValidationError.message("Chưa lưu đủ ảnh siêu âm.") }
        let previousFiles = Set(snapshot.ultrasounds.filter { $0.id == entry.id }.flatMap(\.attachmentIDs))
        snapshot.ultrasounds.removeAll { $0.id == entry.id }; snapshot.ultrasounds.append(entry)
        for file in files where !snapshot.attachments.contains(where: { $0.id == file.id }) { snapshot.attachments.append(file) }
        prune(previousFiles, from: &snapshot)
    }
    public static func remove(_ id: UUID, from snapshot: inout Snapshot) {
        let candidates = Set(snapshot.ultrasounds.filter { $0.id == id }.flatMap(\.attachmentIDs))
        snapshot.ultrasounds.removeAll { $0.id == id }
        prune(candidates, from: &snapshot)
    }
    private static func prune(_ candidates: Set<UUID>, from snapshot: inout Snapshot) {
        let used = Set(snapshot.ultrasounds.flatMap(\.attachmentIDs) + snapshot.vaccinations.flatMap(\.attachmentIDs)
                       + snapshot.records.flatMap(\.attachmentIDs) + snapshot.journal.flatMap(\.attachmentIDs) + snapshot.supplements.flatMap(\.attachmentIDs))
        snapshot.attachments.removeAll { candidates.contains($0.id) && !used.contains($0.id) }
    }
    public static func checklist(_ snapshot: Snapshot) -> [ChecklistItem] {
        snapshot.tasks.filter { $0.status == .todo && ($0.stage == nil || $0.stage == .pregnant) }
            .sorted { ($0.dueDay ?? "9999", $0.title) < ($1.dueDay ?? "9999", $1.title) }
    }
}

public struct PregnancyGuide: Sendable {
    public var heading: String
    public var mother: String
    public var baby: String
    public var source: URL
    /// General stage summaries, as in the prototype; not individual clinical findings.
    public static func forWeek(_ week: Int) -> PregnancyGuide {
        let base = "https://www.nhs.uk/best-start-in-life/pregnancy/week-by-week-guide-to-pregnancy/"
        switch week {
        case 0...3:
            return .init(heading: "Những tuần đầu", mother: "Tuần thai được tính theo ngày dự sinh bạn nhập. Bạn có thể lưu cảm nhận và những điều muốn hỏi trong lần khám tới.", baby: "Các mốc trong app là thông tin tham khảo; kết quả khám và siêu âm sẽ cung cấp thông tin riêng cho thai kỳ của bạn.", source: URL(string: base + "1st-trimester/week-6/")!)
        case 4...12:
            return .init(heading: "Thông tin chung · đầu thai kỳ", mother: "Bạn có thể thấy mệt, căng ngực hoặc buồn nôn. Biểu hiện và mức độ khác nhau ở mỗi người.", baby: "Trong giai đoạn đầu, các cơ quan và hệ vận động đang dần phát triển. Không dùng mô tả này để diễn giải ảnh siêu âm của bạn.", source: URL(string: base + "1st-trimester/week-6/")!)
        case 13...27:
            return .init(heading: "Thông tin chung · giữa thai kỳ", mother: "Cơ thể tiếp tục thay đổi; bạn có thể cảm nhận những cử động của bé trong giai đoạn này. Ghi lại cảm nhận và câu hỏi cho buổi khám.", baby: "Bé tiếp tục lớn và vận động. Nội dung ở đây mô tả chung cho giai đoạn, không thay thế kết quả theo dõi của bác sĩ.", source: URL(string: base + "2nd-trimester/week-20/")!)
        case 28...36:
            return .init(heading: "Thông tin chung · cuối thai kỳ", mother: "Bạn có thể thấy nặng nề, mệt hoặc khó chịu ở lưng. Lưu những thay đổi và trao đổi với người theo dõi thai kỳ khi cần.", baby: "Bé tiếp tục tăng trưởng trong những tuần cuối. Các thông số của bé cần được đọc theo kết quả khám riêng.", source: URL(string: base + "3rd-trimester/week-28/")!)
        default:
            return .init(heading: "Thông tin chung · gần ngày sinh", mother: "Bạn có thể chuẩn bị giấy tờ, đồ dùng và câu hỏi cho cơ sở dự sinh. Tiếp tục theo lịch hẹn đã xác nhận.", baby: "Bé tiếp tục được theo dõi cho đến khi chào đời. Ngày dự sinh là mốc ước tính, không phải ngày sinh chắc chắn.", source: URL(string: base + "3rd-trimester/week-37/")!)
        }
    }
}
