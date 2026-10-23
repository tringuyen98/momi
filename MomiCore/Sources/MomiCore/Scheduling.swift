import Foundation

public enum Day {
    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    public static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1900...2200).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              Self.key(date, calendar: calendar) == key else { return nil }
        return date
    }
    public static func parseVietnamese(_ text: String) -> String? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: { $0 == "/" || $0 == "-" || $0 == "." })
        guard parts.count == 3, parts[2].count == 4, let d = Int(parts[0]), let m = Int(parts[1]), let y = Int(parts[2]) else { return nil }
        let key = String(format: "%04d-%02d-%02d", y, m, d)
        return date(key) == nil ? nil : key
    }
    public static func adding(_ days: Int, to key: String, calendar: Calendar = .current) -> String? {
        guard let d = date(key, calendar: calendar), let next = calendar.date(byAdding: .day, value: days, to: d) else { return nil }
        return Self.key(next, calendar: calendar)
    }
    public static func display(_ key: String) -> String {
        let p = key.split(separator: "-"); return p.count == 3 ? "\(p[2])/\(p[1])/\(p[0])" : key
    }
}

public struct IntakeOccurrence: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var supplementID: UUID
    public var scheduleID: UUID
    public var day: String
    public var scheduledAt: Date
    public var name: String
    public var amount: String
    public var notifications: Bool
}
public enum ScheduleEngine {
    public static func plan(for supplement: Supplement, day: String) -> IntakeSchedule? {
        supplement.schedules.filter { $0.effectiveFrom <= day }
            .max { $0.effectiveFrom < $1.effectiveFrom }
    }
    public static func occurrences(_ supplements: [Supplement], day: String, calendar: Calendar = .current) -> [IntakeOccurrence] {
        guard let base = Day.date(day, calendar: calendar) else { return [] }
        return supplements.flatMap { supplement -> [IntakeOccurrence] in
            guard let plan = plan(for: supplement, day: day), plan.enabled,
                  plan.effectiveThrough.map({ day <= $0 }) ?? true,
                  plan.weekdays.contains(calendar.component(.weekday, from: base)) else { return [] }
            return plan.slots.compactMap { slot in
                guard let date = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: base) else { return nil }
                guard !supplement.pauses.contains(where: { $0.from <= date && ($0.through.map { date < $0 } ?? true) }) else { return nil }
                return IntakeOccurrence(id: "\(plan.id.uuidString)|\(slot.id.uuidString)|\(day)", supplementID: supplement.id,
                    scheduleID: plan.id, day: day, scheduledAt: date, name: supplement.name, amount: plan.amount, notifications: plan.notifications)
            }
        }.sorted { $0.scheduledAt < $1.scheduledAt }
    }
    public static func record(_ occurrence: IntakeOccurrence, status: IntakeStatus, at: Date, in snapshot: inout Snapshot) {
        snapshot.intakes.removeAll { $0.id == occurrence.id }
        snapshot.intakes.append(IntakeLog(occurrence: occurrence, status: status, at: at))
        snapshot.snoozes.removeAll { $0.occurrenceID == occurrence.id }
    }
    /// Editing starts tomorrow by default; callers may not silently rewrite a past schedule.
    public static func replaceFuturePlan(_ plan: IntakeSchedule, in supplement: inout Supplement, today: String) throws {
        guard plan.effectiveFrom > today else { throw ValidationError.message("Lịch sửa phải bắt đầu từ ngày mai để giữ nguyên lịch sử hôm nay.") }
        supplement.schedules.removeAll { $0.effectiveFrom >= plan.effectiveFrom }
        supplement.schedules.append(plan)
    }
}
public enum ValidationError: LocalizedError {
    case message(String)
    public var errorDescription: String? { switch self { case .message(let value): value } }
}

public struct Reminder: Identifiable, Equatable, Sendable {
    public var id: String
    public var date: Date
    public var title: String
    public var body: String
    public var occurrence: IntakeOccurrence?
    public var route: String
}
public struct ReminderPlan: Sendable {
    public var requests: [Reminder]
    public var intakeCoverageThrough: Date?
    public var truncated: Bool
}
public enum ReminderPlanner {
    /// Bounded one-shot queue. No background execution is assumed. Coverage is displayed in the UI.
    public static func make(snapshot: Snapshot, now: Date, calendar: Calendar = .current, limit: Int = 60, horizonDays: Int = 14) -> ReminderPlan {
        let today = Day.key(now, calendar: calendar)
        let recorded = Set(snapshot.intakes.map(\.id))
        var doses: [Reminder] = []
        for offset in 0..<horizonDays {
            guard let day = Day.adding(offset, to: today, calendar: calendar) else { continue }
            for o in ScheduleEngine.occurrences(snapshot.supplements, day: day, calendar: calendar) where o.notifications && !recorded.contains(o.id) {
                let date = snapshot.snoozes.first { $0.occurrenceID == o.id }?.until ?? o.scheduledAt
                guard !snapshot.supplements.contains(where: { $0.id == o.supplementID && $0.pauses.contains(where: { $0.from <= date && ($0.through.map { date < $0 } ?? true) }) }) else { continue }
                if date > now {
                    doses.append(Reminder(id: "intake|" + o.id, date: date, title: "Đến giờ uống", body: o.name + " · " + o.amount, occurrence: o, route: "supplements"))
                }
            }
        }
        // Keep a snoozed occurrence from yesterday when it crosses midnight.
        for snooze in snapshot.snoozes where snooze.until > now && !recorded.contains(snooze.occurrenceID) {
            guard !doses.contains(where: { $0.id == "intake|" + snooze.occurrenceID }),
                  let day = snooze.occurrenceID.split(separator: "|").last.map(String.init),
                  let o = ScheduleEngine.occurrences(snapshot.supplements, day: day, calendar: calendar).first(where: { $0.id == snooze.occurrenceID }), o.notifications else { continue }
            guard !snapshot.supplements.contains(where: { $0.id == o.supplementID && $0.pauses.contains(where: { $0.from <= snooze.until && ($0.through.map { snooze.until < $0 } ?? true) }) }) else { continue }
            doses.append(Reminder(id: "intake|" + o.id, date: snooze.until, title: "Nhắc lại", body: o.name + " · " + o.amount, occurrence: o, route: "supplements"))
        }
        var other: [Reminder] = []
        for a in snapshot.appointments where a.status == .scheduled {
            for minutes in Set(a.reminderMinutes) {
                let d = a.date.addingTimeInterval(-Double(minutes) * 60)
                if d > now { other.append(Reminder(id: "appointment|\(a.id)|\(minutes)", date: d, title: a.title, body: a.place, occurrence: nil, route: "appointments")) }
            }
        }
        for t in snapshot.tasks where t.status == .todo {
            if let date = t.reminder, date > now { other.append(Reminder(id: "task|\(t.id)", date: date, title: t.title, body: "Việc bạn đã lên lịch", occurrence: nil, route: "checklist")) }
        }
        let selectedOther = Array(other.sorted { $0.date < $1.date }.prefix(min(20, limit)))
        let sortedDoses = doses.sorted { $0.date < $1.date }
        let selectedDoses = Array(sortedDoses.prefix(max(0, limit - selectedOther.count)))
        return ReminderPlan(requests: (selectedOther + selectedDoses).sorted { $0.date < $1.date },
            intakeCoverageThrough: selectedDoses.last?.date,
            truncated: selectedDoses.count < doses.count || selectedOther.count < other.count)
    }
}
