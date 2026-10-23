import Foundation
import Observation
import MomiCore

@MainActor @Observable final class AppStore {
    var snapshot: Snapshot
    var error: String?
    var notice: String?
    var selectedTab = 0
    var route: Route?
    var today = Day.key(Date())
    let persistence: Persistence
    let files: AttachmentService
    let notifications: NotificationService
    init(persistence: Persistence, files: AttachmentService) throws {
        self.persistence = persistence; self.files = files
        snapshot = try persistence.load()
        notifications = NotificationService()
        files.cleanup(keeping: snapshot)
        notifications.onAction = { [weak self] action, occurrence in
            guard let self else { return }
            if let occurrence, action == "taken" || action == "snooze" {
                // A stale notification cannot change an occurrence which was already recorded.
                guard !self.snapshot.intakes.contains(where: { $0.id == occurrence.id }) else { return }
                guard ScheduleEngine.occurrences(self.snapshot.supplements, day: occurrence.day).contains(where: { $0.id == occurrence.id }) else { return }
                if action == "taken" { self.record(occurrence, status: .taken) }
                else { self.snooze(occurrence) }
            } else {
                self.selectedTab = 3
                self.route = action == "appointments" ? .appointments : action == "checklist" ? .checklist : .supplements
            }
        }
    }
    @discardableResult func commit(_ change: (inout Snapshot) throws -> Void) -> Bool {
        do {
            var draft = snapshot
            try change(&draft)
            try persistence.save(draft)
            snapshot = draft
            notifications.refresh(draft)
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func refresh() { today = Day.key(Date()); notifications.refresh(snapshot) }
    func record(_ occurrence: IntakeOccurrence, status: IntakeStatus, at: Date = Date()) {
        _ = commit { ScheduleEngine.record(occurrence, status: status, at: at, in: &$0) }
    }
    func snooze(_ occurrence: IntakeOccurrence) {
        Task {
            guard await notifications.requestPermission() else { error = "Hãy bật thông báo trong Cài đặt iPhone để nhận nhắc lại."; return }
            _ = commit {
                $0.snoozes.removeAll { $0.occurrenceID == occurrence.id }
                $0.snoozes.append(Snooze(occurrenceID: occurrence.id, until: Date().addingTimeInterval(900)))
            }
        }
    }
    func importAttachment(data: Data, name: String, extension ext: String) throws -> Attachment {
        try files.save(data, name: name, extension: ext)
    }
    func makeBackup(password: String) async throws -> URL {
        let snapshot = snapshot; let files = files
        let result = try await Task.detached {
            let payload = BackupPayload(snapshot: snapshot, files: try files.files(for: snapshot))
            let data = try BackupCipher.encrypt(payload, password: password)
            guard data.count < 250 * 1024 * 1024 else { throw ValidationError.message("Backup vượt giới hạn 250 MB. Hãy giảm kích thước file đính kèm trước khi xuất.") }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Momi-\(UUID().uuidString).momi")
            try data.write(to: url, options: .atomic)
            return url
        }.value
        return result
    }
    func readBackup(_ url: URL, password: String) async throws -> BackupPayload {
        try await Task.detached {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) < 250 * 1024 * 1024 else { throw ValidationError.message("Backup vượt giới hạn 250 MB của phiên bản này.") }
            return try BackupCipher.decrypt(Data(contentsOf: url), password: password)
        }.value
    }
    func restore(_ payload: BackupPayload) throws {
        let staged = try files.stageRestore(payload)
        do { try persistence.save(staged) }
        catch { files.cleanup(keeping: snapshot); throw error }
        snapshot = staged
        files.cleanup(keeping: staged)
        refresh()
    }
    func markVaccinated(_ dose: VaccinationDose, attachments: [Attachment] = []) -> Bool {
        commit { s in
            s.vaccinations.append(dose)
            for file in attachments where !s.attachments.contains(where: { $0.id == file.id }) { s.attachments.append(file) }
            if let id = dose.appointmentID {
                if let i = s.appointments.firstIndex(where: { $0.id == id }) { s.appointments[i].status = .completed }
                for i in s.tasks.indices where s.tasks[i].appointmentID == id && s.tasks[i].status == .todo { s.tasks[i].status = .done }
            }
        }
    }
}

enum Route: String, Identifiable, Hashable {
    case checklist, cycle, nutrition, supplements, intakeHistory, vaccines, appointments, records, journal, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .checklist: "Checklist của mẹ"; case .cycle: "Chu kỳ & cảm nhận"; case .nutrition: "Dinh dưỡng & bổ sung"
        case .supplements: "Vitamin & bổ sung"; case .intakeHistory: "Lịch sử uống"; case .vaccines: "Vaccine"
        case .appointments: "Lịch hẹn"; case .records: "Hồ sơ sức khỏe"; case .journal: "Nhật ký"; case .settings: "Cài đặt"
        }
    }
}
