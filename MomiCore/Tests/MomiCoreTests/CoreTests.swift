import Foundation
import Testing
@testable import MomiCore

struct CoreTests {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!; return c }
    func date(_ day: String, _ hour: Int = 9) -> Date { calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Day.date(day, calendar: calendar)!)! }
    func product() -> Supplement {
        var s = Supplement(name: "A")
        var plan = IntakeSchedule(from: "2026-10-01", amount: "1 viên")
        plan.slots = [DoseSlot(hour: 8, minute: 0), DoseSlot(hour: 20, minute: 0)]
        s.schedules = [plan]; return s
    }
    @Test func dateValidation() {
        #expect(Day.parseVietnamese("31/02/2026") == nil)
        #expect(Day.parseVietnamese("29/02/2024") == "2024-02-29")
        #expect(Day.parseVietnamese("15/11/20?6") == nil)
        #expect(Day.parseVietnamese("12/08/26") == nil)
        #expect(Day.adding(1, to: "2026-12-31", calendar: calendar) == "2027-01-01")
    }
    @Test func futureChangesPreservePastAndDoseSnapshots() throws {
        var s = product()
        let before = ScheduleEngine.occurrences([s], day: "2026-10-23", calendar: calendar)
        var snapshot = Snapshot()
        ScheduleEngine.record(before[0], status: .taken, at: date("2026-10-23"), in: &snapshot)
        var changed = IntakeSchedule(from: "2026-10-24", amount: "2 viên")
        changed.slots = [DoseSlot(hour: 10, minute: 0)]
        try ScheduleEngine.replaceFuturePlan(changed, in: &s, today: "2026-10-23")
        #expect(ScheduleEngine.occurrences([s], day: "2026-10-23", calendar: calendar) == before)
        #expect(ScheduleEngine.occurrences([s], day: "2026-10-24", calendar: calendar).first?.amount == "2 viên")
        #expect(snapshot.intakes[0].amount == "1 viên")
        changed.effectiveFrom = "2026-10-23"
        #expect(throws: ValidationError.self) { try ScheduleEngine.replaceFuturePlan(changed, in: &s, today: "2026-10-23") }
    }
    @Test func recordIsIdempotent() {
        let o = ScheduleEngine.occurrences([product()], day: "2026-10-23", calendar: calendar)[0]
        var snapshot = Snapshot()
        snapshot.snoozes = [Snooze(occurrenceID: o.id, until: date("2026-10-23", 10))]
        ScheduleEngine.record(o, status: .taken, at: date("2026-10-23"), in: &snapshot)
        ScheduleEngine.record(o, status: .taken, at: date("2026-10-23"), in: &snapshot)
        #expect(snapshot.intakes.count == 1)
        #expect(snapshot.snoozes.isEmpty)
    }
    @Test func weekdaysAndEndDate() {
        var s = product()
        s.schedules[0].weekdays = [6] // Friday
        s.schedules[0].effectiveThrough = "2026-10-23"
        #expect(ScheduleEngine.occurrences([s], day: "2026-10-23", calendar: calendar).count == 2)
        #expect(ScheduleEngine.occurrences([s], day: "2026-10-24", calendar: calendar).isEmpty)
        #expect(ScheduleEngine.occurrences([s], day: "2026-10-30", calendar: calendar).isEmpty)
    }
    @Test func reminderCapAndCancellation() {
        var snapshot = Snapshot(); snapshot.supplements = [product()]
        let first = ReminderPlanner.make(snapshot: snapshot, now: date("2026-10-23", 7), calendar: calendar, limit: 3)
        #expect(first.requests.count == 3)
        #expect(first.truncated)
        let o = first.requests[0].occurrence!
        ScheduleEngine.record(o, status: .taken, at: date("2026-10-23"), in: &snapshot)
        let next = ReminderPlanner.make(snapshot: snapshot, now: date("2026-10-23", 7), calendar: calendar)
        #expect(!next.requests.contains { $0.occurrence?.id == o.id })
        snapshot.supplements[0].schedules[0].notifications = false
        #expect(ReminderPlanner.make(snapshot: snapshot, now: date("2026-10-23", 7), calendar: calendar).requests.isEmpty)
    }
    @Test func snoozeAcrossMidnightKeepsOriginalOccurrence() {
        var snapshot = Snapshot(); snapshot.supplements = [product()]
        let o = ScheduleEngine.occurrences(snapshot.supplements, day: "2026-10-23", calendar: calendar)[1]
        snapshot.snoozes = [Snooze(occurrenceID: o.id, until: date("2026-10-24", 1))]
        let plan = ReminderPlanner.make(snapshot: snapshot, now: date("2026-10-24", 0), calendar: calendar)
        #expect(plan.requests.contains { $0.occurrence?.id == o.id && $0.date == date("2026-10-24", 1) })
    }
    @Test func ocrSeparatesAppointmentDate() {
        let draft = VaccineDocumentParser.parse([
            OCRLine(text: "Ngày tiêm: 12/08/2026", confidence: 0.9),
            OCRLine(text: "Hẹn tiêm lần tiếp theo: 15/11/2026", confidence: 0.8),
            OCRLine(text: "Viêm gan B", confidence: 0.9)
        ])
        #expect(draft.injectedDateText == "12/08/2026")
        #expect(draft.nextDateText == "15/11/2026")
        #expect(!draft.confirmed)
        let unlabeled = VaccineDocumentParser.parse([OCRLine(text: "12/08/2026", confidence: 0.9)])
        #expect(unlabeled.injectedDateText.isEmpty)
    }
    @Test func backupRoundTripAndWrongPassword() throws {
        var snapshot = Snapshot(); snapshot.supplements = [product()]
        let payload = BackupPayload(snapshot: snapshot, files: [:])
        let encrypted = try BackupCipher.encrypt(payload, password: "a-long-test-password")
        let decoded = try BackupCipher.decrypt(encrypted, password: "a-long-test-password")
        #expect(decoded.snapshot == snapshot)
        #expect(throws: (any Error).self) { _ = try BackupCipher.decrypt(encrypted, password: "wrong-password") }
    }
    @Test func backupRejectsMissingFilesAndTraversal() {
        var snapshot = Snapshot()
        snapshot.attachments = [Attachment(filename: "missing.jpg", displayName: "Ảnh")]
        #expect(throws: ValidationError.self) { try BackupPayload(snapshot: snapshot, files: [:]).validate() }
        snapshot.attachments = [Attachment(filename: "../evil.jpg", displayName: "Ảnh")]
        #expect(throws: ValidationError.self) { try BackupPayload(snapshot: snapshot, files: ["../evil.jpg": Data()]).validate() }
    }
    @Test func localDayDoesNotUseUTCDate() {
        let instant = ISO8601DateFormatter().date(from: "2026-10-23T18:00:00Z")!
        #expect(Day.key(instant, calendar: calendar) == "2026-10-24")
    }
    @Test func pauseResumePreservesEarlierOccurrences() {
        var s = product()
        let previous = ScheduleEngine.occurrences([s], day: "2026-10-22", calendar: calendar)
        s.pauses = [PausePeriod(from: date("2026-10-23", 12), through: date("2026-10-24", 12))]
        #expect(ScheduleEngine.occurrences([s], day: "2026-10-22", calendar: calendar) == previous)
        let dayOne = ScheduleEngine.occurrences([s], day: "2026-10-23", calendar: calendar)
        let dayTwo = ScheduleEngine.occurrences([s], day: "2026-10-24", calendar: calendar)
        #expect(dayOne.count == 1 && calendar.component(.hour, from: dayOne[0].scheduledAt) == 8)
        #expect(dayTwo.count == 1 && calendar.component(.hour, from: dayTwo[0].scheduledAt) == 20)
    }
    @Test func cancelledAppointmentsAndCompletedTasksDoNotNotify() {
        var snapshot = Snapshot()
        var a = Appointment(title: "Khám", date: date("2026-10-24")); a.reminderMinutes = [0]; a.status = .cancelled
        var t = ChecklistItem(title: "Việc"); t.reminder = date("2026-10-24"); t.status = .done
        snapshot.appointments = [a]; snapshot.tasks = [t]
        #expect(ReminderPlanner.make(snapshot: snapshot, now: date("2026-10-23"), calendar: calendar).requests.isEmpty)
    }
    @Test func backupRoundTripKeepsAttachmentBytesAndReferences() throws {
        var snapshot = Snapshot()
        let a = Attachment(filename: "image.jpg", displayName: "Phiếu")
        snapshot.attachments = [a]
        var record = HealthRecord(title: "Khám", day: "2026-10-23"); record.attachmentIDs = [a.id]; snapshot.records = [record]
        let bytes = Data([0, 1, 2, 255])
        let payload = BackupPayload(snapshot: snapshot, files: [a.filename: bytes])
        let decoded = try BackupCipher.decrypt(BackupCipher.encrypt(payload, password: "backup-file-test"), password: "backup-file-test")
        #expect(decoded.files[a.filename] == bytes)
        #expect(decoded.snapshot.records[0].attachmentIDs == [a.id])
    }
    @Test func backupRejectsInvalidSchedule() {
        var snapshot = Snapshot(); var s = product(); s.schedules[0].slots[0].hour = 40; snapshot.supplements = [s]
        #expect(throws: ValidationError.self) { try BackupPayload(snapshot: snapshot, files: [:]).validate() }
    }
    @Test func csvEscapesQuotesAndFormulaInjection() {
        #expect(DataExport.csvCell("Vitamin \"A\", B") == "\"Vitamin \"\"A\"\", B\"")
        #expect(DataExport.csvCell("=1+1") == "\"'=1+1\"")
        #expect(DataExport.csvCell("Hai\ndòng") == "\"Hai\ndòng\"")
    }
}
