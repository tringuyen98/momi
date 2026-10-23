import Foundation

public enum DataExport {
    public static func csvCell(_ text: String) -> String {
        // Prevent spreadsheet formulas when user-entered names are opened in Excel/Numbers.
        let safe = text.first.map { "=+-@\t\r".contains($0) } == true ? "'" + text : text
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    public static func intakeCSV(_ snapshot: Snapshot) -> String {
        var rows = [["Ngày theo lịch", "Sản phẩm", "Lượng dùng", "Trạng thái", "Thời gian ghi nhận"]]
        rows += snapshot.intakes.sorted { $0.scheduledAt < $1.scheduledAt }.map {
            [$0.day, $0.productName, $0.amount, $0.status.title, ISO8601DateFormatter().string(from: $0.recordedAt)]
        }
        return "\u{FEFF}" + rows.map { $0.map(csvCell).joined(separator: ",") }.joined(separator: "\r\n")
    }
    public static func healthSummary(_ snapshot: Snapshot, now: Date) -> [String] {
        let today = Day.key(now)
        var lines = ["MOMI — THÔNG TIN CHUẨN BỊ ĐI KHÁM", "Tên: " + snapshot.profile.name, "Giai đoạn: " + snapshot.profile.stage.title, "Xuất ngày: " + Day.display(today), "Thông tin do người dùng ghi nhận; không phải kết luận y khoa.", "SẢN PHẨM ĐÃ LƯU"]
        for s in snapshot.supplements {
            let plan = ScheduleEngine.plan(for: s, day: today)
            let status = s.pauses.contains { $0.through == nil } ? " — đang tạm dừng" : ""
            lines.append(s.name + status)
            if let plan { lines.append("Lượng dùng đã nhập: " + plan.summary + "; giờ: " + plan.slots.map(\.label).joined(separator: ", ")) }
            lines.append(s.instructions)
        }
        lines.append("CÁC MŨI TIÊM ĐÃ GHI NHẬN")
        for dose in snapshot.vaccinations.sorted(by: { $0.day > $1.day }) {
            let name = snapshot.vaccines.first { $0.id == dose.vaccineID }?.name ?? "Vaccine"
            lines.append("\(Day.display(dose.day)) — \(name) — \(dose.place)")
        }
        lines.append("LỊCH HẸN VÀ CÂU HỎI")
        for a in snapshot.appointments.filter({ $0.status == .scheduled }).sorted(by: { $0.date < $1.date }) {
            lines.append(a.title + " — " + Day.display(Day.key(a.date))); lines.append(a.questions)
        }
        return lines.filter { !$0.isEmpty }
    }
}
