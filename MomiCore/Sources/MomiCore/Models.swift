import Foundation

public enum Stage: String, Codable, CaseIterable, Sendable {
    case preparation, pregnant
    public var title: String { self == .preparation ? "Chuẩn bị có em bé" : "Đang mang thai" }
}

public struct Profile: Codable, Equatable, Sendable {
    public var name = ""
    public var stage: Stage = .preparation
    public var dueDate: String?
    public var cycleLength: Int?
    public var onboarded = false
    public var hideNotificationDetails = true
    public var appLock = false
    public var vegetarian = false
    public var allergies: [String] = []
    public var stageHistory: [String] = []
    public init() {}
}

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case todo, done, archived
    public var title: String {
        switch self { case .todo: "Cần làm"; case .done: "Đã xong"; case .archived: "Đã lưu trữ" }
    }
}
public struct ChecklistItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var title: String
    public var group: String = "Việc cá nhân"
    public var notes: String = ""
    public var dueDay: String?
    public var reminder: Date?
    public var status: TaskStatus = .todo
    public var appointmentID: UUID?
    public init(title: String) { self.title = title }
}

public struct Ingredient: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var name: String = ""
    public var amount: String = ""
    public var unit: String = "mcg"
    public init() {}
}
public struct DoseSlot: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var hour: Int
    public var minute: Int
    public init(hour: Int, minute: Int) { self.hour = hour; self.minute = minute }
    public var label: String { String(format: "%02d:%02d", hour, minute) }
}
public struct IntakeSchedule: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var effectiveFrom: String
    public var effectiveThrough: String?
    public var weekdays: [Int] = [1, 2, 3, 4, 5, 6, 7] // Foundation: Sunday = 1
    public var slots: [DoseSlot] = []
    public var amount: String
    public var enabled = true
    public var notifications = true
    public init(from: String, amount: String) { effectiveFrom = from; self.amount = amount }
}
public struct Supplement: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var instructions = ""
    public var ingredients: [Ingredient] = []
    public var schedules: [IntakeSchedule] = []
    public var pauses: [PausePeriod] = []
    public var attachmentIDs: [UUID] = []
    public init(name: String) { self.name = name }
}
public struct PausePeriod: Codable, Equatable, Sendable {
    public var from: Date
    public var through: Date?
    public init(from: Date, through: Date? = nil) { self.from = from; self.through = through }
}
public enum IntakeStatus: String, Codable, CaseIterable, Sendable {
    case taken, skipped
    public var title: String { self == .taken ? "Đã uống" : "Đã bỏ qua" }
}
public struct IntakeLog: Identifiable, Codable, Equatable, Sendable {
    public var id: String // stable occurrence identity, never a notification identifier
    public var supplementID: UUID
    public var day: String
    public var scheduledAt: Date
    public var productName: String
    public var amount: String
    public var status: IntakeStatus
    public var recordedAt: Date
    public init(occurrence: IntakeOccurrence, status: IntakeStatus, at: Date) {
        id = occurrence.id; supplementID = occurrence.supplementID; day = occurrence.day
        scheduledAt = occurrence.scheduledAt; productName = occurrence.name
        amount = occurrence.amount; self.status = status; recordedAt = at
    }
}
public struct Snooze: Codable, Equatable, Sendable {
    public var occurrenceID: String
    public var until: Date
    public init(occurrenceID: String, until: Date) { self.occurrenceID = occurrenceID; self.until = until }
}

public enum AppointmentKind: String, Codable, CaseIterable, Sendable {
    case examination, vaccination, personal
    public var title: String {
        switch self { case .examination: "Khám"; case .vaccination: "Tiêm chủng"; case .personal: "Cá nhân" }
    }
}
public enum AppointmentStatus: String, Codable, CaseIterable, Sendable {
    case scheduled, completed, cancelled
    public var title: String {
        switch self { case .scheduled: "Đã lên lịch"; case .completed: "Đã hoàn thành"; case .cancelled: "Đã hủy" }
    }
}
public struct Appointment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var title: String
    public var kind: AppointmentKind = .examination
    public var date: Date
    public var place = ""
    public var notes = ""
    public var questions = ""
    public var reminderMinutes: [Int] = []
    public var status: AppointmentStatus = .scheduled
    public var vaccineID: UUID?
    public var previousDate: Date?
    public init(title: String, date: Date) { self.title = title; self.date = date }
}
public struct VaccineRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var notes = ""
    public init(name: String) { self.name = name }
}
public struct VaccinationDose: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var vaccineID: UUID
    public var number: Int?
    public var day: String
    public var product = ""
    public var place = ""
    public var lot = ""
    public var notes = ""
    public var attachmentIDs: [UUID] = []
    public var appointmentID: UUID?
    public init(vaccineID: UUID, day: String) { self.vaccineID = vaccineID; self.day = day }
}
public struct Attachment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var filename: String
    public var displayName: String
    public var createdAt = Date()
    public init(filename: String, displayName: String) { self.filename = filename; self.displayName = displayName }
}
public struct HealthRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var title: String
    public var day: String
    public var kind = "Khám"
    public var place = ""
    public var notes = ""
    public var advice = ""
    public var attachmentIDs: [UUID] = []
    public var appointmentID: UUID?
    public init(title: String, day: String) { self.title = title; self.day = day }
}
public struct JournalEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var day: String
    public var text: String
    public var mood = ""
    public var stage: Stage = .preparation
    public var attachmentIDs: [UUID] = []
    public init(day: String, text: String) { self.day = day; self.text = text }
}
public struct DailyHealthLog: Identifiable, Codable, Equatable, Sendable {
    public var id: String { day }
    public var day: String
    public var bleeding = false
    public var periodStart = false
    public var mood = ""
    public var symptoms: [String] = []
    public var notes = ""
    public init(day: String) { self.day = day }
}
public struct MealPlanEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var day: String
    public var foodID: String
    public init(day: String, foodID: String) { self.day = day; self.foodID = foodID }
}
public struct Snapshot: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var profile = Profile()
    public var tasks: [ChecklistItem] = []
    public var supplements: [Supplement] = []
    public var intakes: [IntakeLog] = []
    public var snoozes: [Snooze] = []
    public var appointments: [Appointment] = []
    public var vaccines: [VaccineRecord] = []
    public var vaccinations: [VaccinationDose] = []
    public var attachments: [Attachment] = []
    public var records: [HealthRecord] = []
    public var journal: [JournalEntry] = []
    public var dailyLogs: [DailyHealthLog] = []
    public var meals: [MealPlanEntry] = []
    public var bookmarks: [String] = []
    public var savedFoods: [String] = []
    public init() {}
}
