import SwiftUI
import MomiCore

struct CycleSummaryCard: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        MomiCard {
            Label("Lịch kinh & rụng trứng", systemImage: "calendar").font(.headline).foregroundStyle(MomiTheme.green)
            if let forecast = CycleEngine.forecast(store.snapshot, today: store.today) {
                Text("Kỳ gần nhất: " + Day.display(forecast.lastStart)).foregroundStyle(MomiTheme.ink)
                Text("Kỳ kế tiếp dự kiến: " + Day.display(forecast.nextStart)).font(.subheadline)
                Text("Rụng trứng ước tính: " + Day.display(forecast.ovulation)).font(.subheadline)
                if forecast.nextStart < store.today {
                    Text("Mốc dự kiến đã qua. Ghi kỳ kinh mới nếu đã bắt đầu để cập nhật lịch.").font(.footnote).foregroundStyle(MomiTheme.rose)
                }
                Text("Xem lịch và cập nhật chu kỳ").font(.footnote).foregroundStyle(MomiTheme.green)
            } else {
                Text("Bạn chưa ghi ngày bắt đầu kỳ kinh gần nhất.").foregroundStyle(MomiTheme.ink)
                Text("Thêm ngày để xem lịch và dự báo tham khảo.").font(.subheadline).foregroundStyle(MomiTheme.muted)
            }
        }
    }
}

struct CycleView: View {
    @Environment(AppStore.self) private var store
    @State private var date = Date()
    @State private var month = Date()
    @State private var editing = false
    @State private var addingPeriod = false
    @State private var settings = false
    private var preparation: Bool { store.snapshot.profile.stage == .preparation }
    private var forecast: CycleForecast? { CycleEngine.forecast(store.snapshot, today: store.today) }
    var body: some View {
        MomiPage {
            if preparation {
                CycleSummaryCard()
                HStack {
                    Button("Ghi kỳ kinh", systemImage: "drop.fill") { addingPeriod = true }.buttonStyle(.borderedProminent)
                    Spacer()
                    Button("Thiết lập chu kỳ") { settings = true }
                }
            }
            MomiCard { CycleMonthCalendar(month: $month, selected: $date, forecast: forecast, logs: store.snapshot.dailyLogs) }
            MomiCard {
                Text(Day.display(Day.key(date))).font(.headline)
                if let log = store.snapshot.dailyLogs.first(where: { $0.day == Day.key(date) }) {
                    if log.periodStart { Label("Bắt đầu kỳ kinh đã ghi", systemImage: "drop.fill").foregroundStyle(MomiTheme.rose) }
                    else if log.bleeding { Label("Có kinh đã ghi", systemImage: "drop.fill").foregroundStyle(MomiTheme.rose) }
                    if !log.mood.isEmpty { Text(log.mood) }
                    if !log.symptoms.isEmpty { Text(log.symptoms.joined(separator: ", ")) }
                    if !log.notes.isEmpty { Text(log.notes) }
                } else { Text("Chưa có ghi chép cho ngày này.").foregroundStyle(MomiTheme.muted) }
                if let f = forecast {
                    let key = Day.key(date)
                    if key >= f.nextStart && key <= f.periodEnd { Text("Kỳ kinh dự kiến · chưa phải ngày đã ghi").foregroundStyle(MomiTheme.rose).font(.subheadline) }
                    if key == f.ovulation { Text("Ngày rụng trứng ước tính").foregroundStyle(MomiTheme.green).font(.subheadline) }
                    if key >= f.fertileStart && key <= f.fertileEnd { Text("Trong khoảng dễ thụ thai ước tính").foregroundStyle(MomiTheme.green).font(.subheadline) }
                }
                if Day.key(date) <= store.today { Button("Ghi / sửa ngày này") { editing = true } }
                else { Text("Bạn có thể ghi cảm nhận khi đến ngày này.").font(.footnote).foregroundStyle(MomiTheme.muted) }
            }
            if preparation {
                MomiCard {
                    Text("Dự báo để tham khảo").font(.headline)
                    Text("Dùng chu kỳ \(store.snapshot.profile.cycleLength ?? 28) ngày và kỳ kinh \(store.snapshot.profile.periodLength ?? 5) ngày. Rụng trứng được ước tính khoảng 14 ngày trước kỳ kế tiếp; khoảng dễ thụ thai từ 5 ngày trước đến 1 ngày sau mốc này.").font(.footnote)
                    if store.snapshot.profile.cycleLength == nil { Text("Chưa có độ dài chu kỳ của bạn: đang dùng giả định 28 ngày. Chỉnh trong Thiết lập chu kỳ.").font(.footnote).foregroundStyle(MomiTheme.rose) }
                    Text("Ngày thực tế có thể khác, đặc biệt khi chu kỳ không đều. Lịch không xác nhận rụng trứng và không dùng để tránh thai. Dự báo chỉ dựa trên kỳ gần nhất bạn đã ghi.").font(.footnote).foregroundStyle(MomiTheme.muted)
                    Link("Nguồn: NHS · Chuẩn bị mang thai", destination: URL(string: "https://www.nhs.uk/pregnancy/trying-for-a-baby/trying-to-get-pregnant/")!).font(.footnote)
                    Link("Nguồn: ACOG · Khoảng dễ thụ thai", destination: URL(string: "https://www.acog.org/womens-health/faqs/fertility-awareness-based-methods-of-family-planning")!).font(.footnote)
                }
                SectionHeading(title: "Các kỳ kinh đã ghi")
                if store.snapshot.dailyLogs.filter(\.periodStart).isEmpty { Text("Chưa có kỳ kinh. Bạn có thể bổ sung bất cứ lúc nào.").foregroundStyle(MomiTheme.muted) }
                ForEach(store.snapshot.dailyLogs.filter(\.periodStart).sorted { $0.day > $1.day }) { log in
                    Button { if let d = Day.date(log.day) { date = d; month = d; editing = true } } label: {
                        HStack { Label(Day.display(log.day), systemImage: "drop.fill"); Spacer(); Text("Sửa").font(.subheadline) }
                    }.buttonStyle(.plain).foregroundStyle(MomiTheme.rose)
                }
            }
        }.navigationTitle(preparation ? "Lịch chu kỳ" : "Cảm nhận mỗi ngày")
            .sheet(isPresented: $editing) { NavigationStack { DailyLogEditor(day: Day.key(date)) } }
            .sheet(isPresented: $addingPeriod) { NavigationStack { PeriodStartEditor { d in date = d; month = d } } }
            .sheet(isPresented: $settings) { NavigationStack { CycleSettingsEditor() } }
    }
}

struct CycleSettingsEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var length = 28
    @State private var duration = 5
    var body: some View {
        Form {
            Section("Chu kỳ của bạn") {
                Stepper("Độ dài chu kỳ: \(length) ngày", value: $length, in: 15...60)
                Text("Tính từ ngày đầu một kỳ kinh đến ngày đầu kỳ tiếp theo.").font(.footnote)
                Stepper("Số ngày có kinh thường gặp: \(duration)", value: $duration, in: 1...14)
            }
            Section { Text("Dùng số ngày thường gặp của bạn. Với chu kỳ không đều, dự báo lịch có thể sai lệch nhiều; hãy đối chiếu với dấu hiệu cơ thể và trao đổi với bác sĩ khi cần.").font(.footnote) }
        }.momiForm().navigationTitle("Thiết lập chu kỳ")
            .onAppear { length = min(60, max(15, store.snapshot.profile.cycleLength ?? 28)); duration = min(14, max(1, store.snapshot.profile.periodLength ?? 5)) }
            .editorToolbar(save: { if store.commit({ $0.profile.cycleLength = length; $0.profile.periodLength = duration }) { dismiss() } }, cancel: { dismiss() })
    }
}

struct PeriodStartEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSave: (Date) -> Void
    @State private var date = Date()
    var body: some View {
        Form {
            DatePicker("Ngày bắt đầu kỳ kinh", selection: $date, in: ...Date(), displayedComponents: .date).datePickerStyle(.graphical)
            Text("Chọn ngày đầu kỳ kinh gần nhất hoặc bổ sung một kỳ trước đó. Các kỳ đã ghi được giữ lại; chạm Sửa ở lịch sử để sửa một lần ghi nhầm.").font(.footnote)
        }.momiForm().navigationTitle("Ghi kỳ kinh")
            .editorToolbar(save: {
                let key = Day.key(date)
                if store.commit({ s in
                    var log = s.dailyLogs.first { $0.day == key } ?? DailyHealthLog(day: key)
                    log.periodStart = true; log.bleeding = true
                    s.dailyLogs.removeAll { $0.day == key }; s.dailyLogs.append(log)
                }) { onSave(date); dismiss() }
            }, cancel: { dismiss() })
    }
}

struct CycleMonthCalendar: View {
    @Binding var month: Date
    @Binding var selected: Date
    var forecast: CycleForecast?
    var logs: [DailyHealthLog]
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; return c }
    private var days: [Date?] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let offset = (calendar.component(.weekday, from: start) + 5) % 7
        return Array(repeating: nil, count: offset) + range.map { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
    }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Tháng trước")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "vi_VN")))).font(.headline)
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Tháng sau")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                ForEach(["T2", "T3", "T4", "T5", "T6", "T7", "CN"], id: \.self) { Text($0).font(.caption).foregroundStyle(MomiTheme.muted) }
                ForEach(days.indices, id: \.self) { index in
                    if let day = days[index] { dayCell(day) } else { Color.clear.frame(height: 48) }
                }
            }
            HStack { legend("Kinh đã ghi", "circle.fill", MomiTheme.rose); Spacer(); legend("Kinh dự kiến", "circle", MomiTheme.rose) }
            if forecast != nil { HStack { legend("Dễ thụ thai ước tính", "leaf.fill", MomiTheme.green); Spacer(); legend("Rụng trứng ước tính", "diamond.fill", MomiTheme.green) } }
            Button("Về hôm nay") { month = Date(); selected = Date() }.font(.subheadline)
        }
    }
    private func dayCell(_ day: Date) -> some View {
        let key = Day.key(day)
        let recorded = logs.contains { $0.day == key && ($0.bleeding || $0.periodStart) }
        let period = forecast.map { key >= $0.nextStart && key <= $0.periodEnd } ?? false
        let fertile = forecast.map { key >= $0.fertileStart && key <= $0.fertileEnd } ?? false
        let ovulation = forecast?.ovulation == key
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let background = recorded ? MomiTheme.rose.opacity(0.22) : period ? MomiTheme.rose.opacity(0.08) : fertile ? MomiTheme.green.opacity(0.13) : Color.clear
        return Button { selected = day } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))").font(.body.weight(calendar.isDateInToday(day) ? .bold : .regular)).foregroundStyle(MomiTheme.ink)
                HStack(spacing: 3) {
                    if recorded || period { Image(systemName: recorded ? "circle.fill" : "circle").foregroundStyle(MomiTheme.rose) }
                    if fertile { Image(systemName: ovulation ? "diamond.fill" : "leaf.fill").foregroundStyle(MomiTheme.green) }
                    if !recorded && !period && !fertile { Color.clear.frame(width: 8, height: 8) }
                }.font(.system(size: 8)).frame(height: 9)
            }.frame(maxWidth: .infinity).frame(minHeight: 48)
                .background(background, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(isSelected ? MomiTheme.green : Color.clear, lineWidth: 2) }
        }.buttonStyle(.plain)
            .accessibilityLabel(Day.display(key) + (recorded ? ", có kinh đã ghi" : "") + (period ? ", kỳ kinh dự kiến" : "") + (fertile ? ", khoảng dễ thụ thai ước tính" : "") + (ovulation ? ", rụng trứng ước tính" : ""))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    private func legend(_ title: String, _ symbol: String, _ color: Color) -> some View { Label(title, systemImage: symbol).font(.caption2).foregroundStyle(color) }
    private func move(_ value: Int) { if let next = calendar.date(byAdding: .month, value: value, to: month) { month = next } }
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
