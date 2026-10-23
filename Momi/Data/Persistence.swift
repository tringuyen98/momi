import Foundation
import SwiftData
import MomiCore

/// Domain records remain Codable value types; each record has its own SwiftData row.
/// This keeps backup/migrations testable independently from Apple's persistence runtime.
@Model final class StoredEntity {
    @Attribute(.unique) var key: String
    var kind: String
    var payload: Data
    init(key: String, kind: String, payload: Data) { self.key = key; self.kind = kind; self.payload = payload }
}

@MainActor final class Persistence {
    let container: ModelContainer
    let context: ModelContext
    init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        container = try ModelContainer(for: StoredEntity.self, configurations: configuration)
        context = ModelContext(container)
        context.autosaveEnabled = false
    }
    func load() throws -> Snapshot {
        let rows = try context.fetch(FetchDescriptor<StoredEntity>())
        let decoder = JSONDecoder()
        func list<T: Decodable>(_ type: T.Type, _ kind: String) throws -> [T] {
            try rows.filter { $0.kind == kind }.map { try decoder.decode(T.self, from: $0.payload) }
        }
        var s = Snapshot()
        if let meta = rows.first(where: { $0.key == "schema" }) {
            guard try decoder.decode(Int.self, from: meta.payload) == 1 else { throw ValidationError.message("Dữ liệu được tạo bởi phiên bản Momi mới hơn.") }
        }
        s.profile = try list(Profile.self, "profile").first ?? Profile()
        s.tasks = try list(ChecklistItem.self, "task")
        s.supplements = try list(Supplement.self, "supplement")
        s.intakes = try list(IntakeLog.self, "intake")
        s.snoozes = try list(Snooze.self, "snooze")
        s.appointments = try list(Appointment.self, "appointment")
        s.vaccines = try list(VaccineRecord.self, "vaccine")
        s.vaccinations = try list(VaccinationDose.self, "vaccination")
        s.attachments = try list(Attachment.self, "attachment")
        s.records = try list(HealthRecord.self, "record")
        s.journal = try list(JournalEntry.self, "journal")
        s.dailyLogs = try list(DailyHealthLog.self, "dailyLog")
        s.meals = try list(MealPlanEntry.self, "meal")
        s.bookmarks = try list([String].self, "bookmarks").first ?? []
        s.savedFoods = try list([String].self, "savedFoods").first ?? []
        s.ultrasounds = try list(UltrasoundEntry.self, "ultrasound")
        return s
    }
    func save(_ snapshot: Snapshot) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        var wanted: [String: (String, Data)] = [:]
        func add<T: Encodable>(_ value: T, kind: String, id: String) throws {
            wanted[kind + "|" + id] = (kind, try encoder.encode(value))
        }
        func addList<T: Encodable & Identifiable>(_ values: [T], kind: String) throws {
            for value in values { try add(value, kind: kind, id: String(describing: value.id)) }
        }
        wanted["schema"] = ("schema", try encoder.encode(snapshot.schemaVersion))
        try add(snapshot.profile, kind: "profile", id: "main")
        try addList(snapshot.tasks, kind: "task"); try addList(snapshot.supplements, kind: "supplement")
        try addList(snapshot.intakes, kind: "intake")
        for snooze in snapshot.snoozes { try add(snooze, kind: "snooze", id: snooze.occurrenceID) }
        try addList(snapshot.appointments, kind: "appointment"); try addList(snapshot.vaccines, kind: "vaccine")
        try addList(snapshot.vaccinations, kind: "vaccination"); try addList(snapshot.attachments, kind: "attachment")
        try addList(snapshot.records, kind: "record"); try addList(snapshot.journal, kind: "journal")
        try addList(snapshot.dailyLogs, kind: "dailyLog"); try addList(snapshot.meals, kind: "meal")
        try addList(snapshot.ultrasounds, kind: "ultrasound")
        try add(snapshot.bookmarks, kind: "bookmarks", id: "main"); try add(snapshot.savedFoods, kind: "savedFoods", id: "main")
        do {
            let rows = try context.fetch(FetchDescriptor<StoredEntity>())
            for row in rows {
                if let pair = wanted.removeValue(forKey: row.key) {
                    if row.payload != pair.1 { row.payload = pair.1 }
                } else { context.delete(row) }
            }
            for (key, pair) in wanted { context.insert(StoredEntity(key: key, kind: pair.0, payload: pair.1)) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
}
