import SwiftUI
import MomiCore

struct CycleView: View {
    @Environment(AppStore.self) private var store
    @State private var date = Date()
    @State private var editing = false
    var body: some View {
        MomiPage {
            DatePicker("Ngày ghi nhận", selection: $date, in: ...Date(), displayedComponents: .date).datePickerStyle(.graphical)
            MomiCard {
                if let log = store.snapshot.dailyLogs.first(where: { $0.day == Day.key(date) }) {
                    if log.periodStart { Text("Bắt đầu kỳ kinh").font(.headline) }
                    if log.bleeding { Label("Có kinh", systemImage: "drop") }
                    Text(log.mood); if !log.symptoms.isEmpty { Text(log.symptoms.joined(separator: ", ")) }; Text(log.notes)
                } else { Text("Chưa có ghi chép cho ngày này.").foregroundStyle(MomiTheme.muted) }
                Button("Ghi / sửa ngày này") { editing = true }
            }
            SectionHeading(title: "Các kỳ kinh đã ghi")
            ForEach(store.snapshot.dailyLogs.filter(\.periodStart).sorted { $0.day > $1.day }) { log in Text(Day.display(log.day)).font(.body) }
            Text("Momi chỉ hiển thị dữ liệu bạn đã ghi. Phiên bản này không dự đoán ngày rụng trứng.").font(.footnote).foregroundStyle(MomiTheme.muted)
        }.navigationTitle("Chu kỳ & cảm nhận").sheet(isPresented: $editing) { NavigationStack { DailyLogEditor(day: Day.key(date)) } }
    }
}
struct DailyLogEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var day: String
    @State private var log = DailyHealthLog(day: "")
    var body: some View {
        Form {
            Section(Day.display(day)) {
                Toggle("Có kinh", isOn: $log.bleeding)
                Toggle("Ngày bắt đầu kỳ kinh", isOn: $log.periodStart).onChange(of: log.periodStart) { _, value in if value { log.bleeding = true } }
                TextField("Cảm nhận hôm nay", text: $log.mood)
            }
            Section("Triệu chứng · tùy chọn") {
                ForEach(["Mệt", "Buồn nôn", "Đau lưng", "Đau đầu", "Căng ngực", "Khó ngủ"], id: \.self) { symptom in
                    Toggle(symptom, isOn: Binding(get: { log.symptoms.contains(symptom) }, set: { if $0 { log.symptoms.append(symptom) } else { log.symptoms.removeAll { $0 == symptom } } }))
                }
            }
            Section("Vài dòng ghi chú") { TextEditor(text: $log.notes).frame(minHeight: 100) }
        }.momiForm().navigationTitle("Ghi lại khi bạn muốn")
            .onAppear { log = store.snapshot.dailyLogs.first { $0.day == day } ?? DailyHealthLog(day: day) }
            .editorToolbar(save: { if !log.bleeding { log.periodStart = false }; if store.commit({ $0.dailyLogs.removeAll { $0.day == day }; $0.dailyLogs.append(log) }) { dismiss() } }, cancel: { dismiss() })
    }
}
struct RecordsView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    var body: some View {
        List {
            if store.snapshot.records.isEmpty { EmptyNote(title: "Giấy tờ ở một nơi", message: "Lưu kết quả khám và những lời dặn cần nhớ.", symbol: "folder") }
            ForEach(store.snapshot.records.sorted { $0.day > $1.day }) { record in NavigationLink { RecordDetail(id: record.id) } label: { VStack(alignment: .leading, spacing: 5) { Text(record.title).font(.headline); Text(Day.display(record.day) + " · " + record.kind).font(.caption).foregroundStyle(MomiTheme.muted) } } }
        }.momiForm().navigationTitle("Hồ sơ sức khỏe").toolbar { Button { adding = true } label: { Image(systemName: "plus").accessibilityLabel("Thêm hồ sơ") } }
            .sheet(isPresented: $adding) { NavigationStack { RecordEditor(record: HealthRecord(title: "", day: store.today)) } }
    }
}
struct RecordDetail: View {
    @Environment(AppStore.self) private var store
    var id: UUID
    @State private var editing = false
    @State private var task = false
    @State private var appointment = false
    var body: some View {
        if let record = store.snapshot.records.first(where: { $0.id == id }) {
            MomiPage {
                Text(record.title).font(.title.bold()); Text(Day.display(record.day)); Text(record.place)
                MomiCard { Text("Ghi chú").font(.headline); Text(record.notes); Text("Lời dặn đã lưu").font(.headline); Text(record.advice); AttachmentLinks(ids: record.attachmentIDs) }
                Button("Thêm việc cần làm") { task = true }; Button("Tạo lịch tái khám") { appointment = true }
            }.navigationTitle("Hồ sơ").toolbar { Button("Sửa") { editing = true } }
                .sheet(isPresented: $editing) { NavigationStack { RecordEditor(record: record) } }
                .sheet(isPresented: $task) { NavigationStack { TaskEditor(item: { var t = ChecklistItem(title: "Việc sau " + record.title); t.notes = record.advice; return t }()) } }
                .sheet(isPresented: $appointment) { NavigationStack { AppointmentEditor(appointment: { var a = Appointment(title: "Tái khám", date: Date().addingTimeInterval(7 * 86400)); a.place = record.place; return a }()) } }
        }
    }
}
struct RecordEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var record: HealthRecord
    @State private var date = Date()
    @State private var files: [Attachment] = []
    @State private var validation: String?
    var body: some View {
        Form {
            TextField("Tên hồ sơ", text: $record.title)
            DatePicker("Ngày", selection: $date, in: ...Date(), displayedComponents: .date)
            Picker("Loại", selection: $record.kind) { ForEach(["Khám", "Xét nghiệm", "Siêu âm", "Khác"], id: \.self) { Text($0) } }
            TextField("Cơ sở khám", text: $record.place)
            TextField("Ghi chú", text: $record.notes, axis: .vertical).lineLimit(2...5)
            TextField("Lời dặn", text: $record.advice, axis: .vertical).lineLimit(3...8)
            Section("Ảnh và PDF") { AttachmentPicker(files: $files) }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle("Lưu hồ sơ")
            .onAppear { date = min(Day.date(record.day) ?? Date(), Date()); files = store.snapshot.attachments.filter { record.attachmentIDs.contains($0.id) } }
            .editorToolbar(save: {
                guard !record.title.trimmingCharacters(in: .whitespaces).isEmpty else { validation = "Hãy nhập tên hồ sơ."; return }
                record.day = Day.key(date); record.attachmentIDs = files.map(\.id)
                if store.commit({ s in s.records.removeAll { $0.id == record.id }; s.records.append(record); for file in files where !s.attachments.contains(where: { $0.id == file.id }) { s.attachments.append(file) } }) { dismiss() }
            }, cancel: { dismiss() })
    }
}
struct JournalView: View {
    @Environment(AppStore.self) private var store
    @State private var newEntry = false
    @State private var editing: JournalEntry?
    var body: some View {
        MomiPage {
            if store.snapshot.journal.isEmpty { EmptyNote(title: "Một góc dành cho bạn", message: "Không cần viết mỗi ngày. Ghi lại khi bạn muốn.", symbol: "square.and.pencil") }
            ForEach(store.snapshot.journal.sorted { $0.day > $1.day }) { entry in
                MomiCard { HStack { Text(Day.display(entry.day)).font(.caption).foregroundStyle(MomiTheme.muted); Spacer(); Button("Sửa") { editing = entry } }; if !entry.mood.isEmpty { Text(entry.mood).font(.headline) }; Text(entry.text); Text(entry.stage.title).font(.caption).foregroundStyle(MomiTheme.green); AttachmentLinks(ids: entry.attachmentIDs) }
            }
        }.navigationTitle("Nhật ký").toolbar { Button { newEntry = true } label: { Image(systemName: "square.and.pencil").accessibilityLabel("Viết nhật ký") } }
            .sheet(isPresented: $newEntry) { NavigationStack { JournalEditor(entry: { var e = JournalEntry(day: store.today, text: ""); e.stage = store.snapshot.profile.stage; return e }()) } }
            .sheet(item: $editing) { entry in NavigationStack { JournalEditor(entry: entry) } }
    }
}
struct JournalEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var entry: JournalEntry
    @State private var date = Date()
    @State private var files: [Attachment] = []
    @State private var validation: String?
    var body: some View {
        Form {
            DatePicker("Ngày", selection: $date, in: ...Date(), displayedComponents: .date)
            TextField("Cảm nhận · tùy chọn", text: $entry.mood)
            TextEditor(text: $entry.text).frame(minHeight: 200)
            Section("Ảnh kỷ niệm") { AttachmentPicker(files: $files) }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle("Viết vài dòng")
            .onAppear { date = min(Day.date(entry.day) ?? Date(), Date()); files = store.snapshot.attachments.filter { entry.attachmentIDs.contains($0.id) } }
            .editorToolbar(save: {
                guard !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !files.isEmpty else { validation = "Thêm vài dòng hoặc một ảnh."; return }
                entry.day = Day.key(date); entry.attachmentIDs = files.map(\.id)
                if store.commit({ s in s.journal.removeAll { $0.id == entry.id }; s.journal.append(entry); for file in files where !s.attachments.contains(where: { $0.id == file.id }) { s.attachments.append(file) } }) { dismiss() }
            }, cancel: { dismiss() })
    }
}
