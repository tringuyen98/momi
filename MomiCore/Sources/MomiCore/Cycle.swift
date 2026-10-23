import Foundation

public struct CycleForecast: Equatable, Sendable {
    public var lastStart: String
    public var cycleLength: Int
    public var periodLength: Int
    public var nextStart: String
    public var ovulation: String
    public var fertileStart: String
    public var fertileEnd: String
    public var periodEnd: String
}

public enum CycleEngine {
    /// One forecast anchored to a real period start. Never invents subsequent cycles.
    /// Ovulation: about 14 days before the next period (NHS).
    /// Fertile interval: 5 days before through 1 day after estimated ovulation (ACOG).
    public static func forecast(_ snapshot: Snapshot, today: String, calendar: Calendar = .current) -> CycleForecast? {
        guard snapshot.profile.stage == .preparation,
              let start = snapshot.dailyLogs.filter({ $0.periodStart && $0.day <= today && Day.date($0.day, calendar: calendar) != nil }).map(\.day).max() else { return nil }
        let length = snapshot.profile.cycleLength ?? 28
        let duration = snapshot.profile.periodLength ?? 5
        guard (15...60).contains(length), (1...14).contains(duration),
              let next = Day.adding(length, to: start, calendar: calendar),
              let ovulation = Day.adding(-14, to: next, calendar: calendar),
              let fertileStart = Day.adding(-5, to: ovulation, calendar: calendar),
              let fertileEnd = Day.adding(1, to: ovulation, calendar: calendar),
              let end = Day.adding(duration - 1, to: next, calendar: calendar) else { return nil }
        return CycleForecast(lastStart: start, cycleLength: length, periodLength: duration, nextStart: next,
                             ovulation: ovulation, fertileStart: max(start, fertileStart), fertileEnd: fertileEnd, periodEnd: end)
    }
}

public enum DashboardChecklist {
    public static func due(_ tasks: [ChecklistItem], on day: String) -> [ChecklistItem] {
        tasks.filter { $0.status == .todo && ($0.dueDay.map { $0 <= day } ?? true) }
            .sorted { ($0.dueDay ?? "9999", $0.title) < ($1.dueDay ?? "9999", $1.title) }
    }
    public static func upcoming(_ tasks: [ChecklistItem], after day: String) -> [ChecklistItem] {
        tasks.filter { $0.status == .todo && $0.dueDay.map { $0 > day } == true }
            .sorted { ($0.dueDay ?? "9999", $0.title) < ($1.dueDay ?? "9999", $1.title) }
    }
}

public enum VaccineManagement {
    public static func removeDose(_ id: UUID, from snapshot: inout Snapshot) {
        let attachments = Set(snapshot.vaccinations.filter { $0.id == id }.flatMap(\.attachmentIDs))
        snapshot.vaccinations.removeAll { $0.id == id }
        removeUnusedAttachments(attachments, from: &snapshot)
    }
    public static func removeVaccine(_ id: UUID, from snapshot: inout Snapshot) {
        let attachments = Set(snapshot.vaccinations.filter { $0.vaccineID == id }.flatMap(\.attachmentIDs))
        snapshot.vaccinations.removeAll { $0.vaccineID == id }
        snapshot.vaccines.removeAll { $0.id == id }
        let scheduled = Set(snapshot.appointments.filter { $0.vaccineID == id && $0.status == .scheduled }.map(\.id))
        for i in snapshot.appointments.indices where snapshot.appointments[i].vaccineID == id {
            if snapshot.appointments[i].status == .scheduled { snapshot.appointments[i].status = .cancelled }
            snapshot.appointments[i].vaccineID = nil
        }
        for i in snapshot.tasks.indices where snapshot.tasks[i].appointmentID.map({ scheduled.contains($0) }) == true {
            snapshot.tasks[i].reminder = nil
            if snapshot.tasks[i].status == .todo { snapshot.tasks[i].status = .archived }
        }
        removeUnusedAttachments(attachments, from: &snapshot)
    }
    private static func removeUnusedAttachments(_ candidates: Set<UUID>, from snapshot: inout Snapshot) {
        let used = Set(snapshot.vaccinations.flatMap(\.attachmentIDs) + snapshot.records.flatMap(\.attachmentIDs)
                       + snapshot.journal.flatMap(\.attachmentIDs) + snapshot.supplements.flatMap(\.attachmentIDs) + snapshot.ultrasounds.flatMap(\.attachmentIDs))
        snapshot.attachments.removeAll { candidates.contains($0.id) && !used.contains($0.id) }
    }
}
