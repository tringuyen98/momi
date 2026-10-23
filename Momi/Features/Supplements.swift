import SwiftUI
import MomiCore

struct SupplementsView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    @State private var pausedOnly = false
    var body: some View {
        MomiPage {
            MomiCard {
                Text("Lịch uống theo thông tin bạn đã nhập").font(.headline)
                Text("Lượng dùng theo nhãn hoặc lời dặn chuyên môn. Momi không tự đề xuất liều.").font(.subheadline).foregroundStyle(MomiTheme.muted)
                NavigationLink("Xem lịch sử uống") { IntakeHistoryView() }
            }
            ReminderCoverageView()
            SectionHeading(title: "Hôm nay")
            DailyIntakeSection(day: store.today)
            Toggle("Chỉ xem sản phẩm tạm dừng", isOn: $pausedOnly)
            ForEach(store.snapshot.supplements.filter { !pausedOnly || $0.pauses.contains { $0.through == nil } }) { s in
                NavigationLink { SupplementDetail(id: s.id) } label: {
                    MomiCard {
                        Label(s.name, systemImage: "pills").font(.headline)
                        if s.pauses.contains(where: { $0.through == nil }) { Text("Đang tạm dừng").font(.caption).foregroundStyle(MomiTheme.rose) }
                        else if let plan = ScheduleEngine.plan(for: s, day: store.today) { Text(plan.amount + " · " + plan.slots.map(\.label).joined(separator: ", ")).font(.subheadline).foregroundStyle(MomiTheme.muted) }
                    }
                }.buttonStyle(.plain)
            }
            if store.snapshot.supplements.isEmpty { EmptyNote(title: "Chưa thêm sản phẩm", message: "Thêm sản phẩm đang dùng để tạo checklist và nhắc hằng ngày.", symbol: "pills") }
        }.navigationTitle("Vitamin & bổ sung")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus").accessibilityLabel("Thêm sản phẩm") } } }
            .sheet(isPresented: $adding) { NavigationStack { SupplementEditor(supplement: Supplement(name: ""), isNew: true) } }
    }
}
struct ReminderCoverageView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        MomiCard {
            Label(store.notifications.permission, systemImage: "bell").font(.subheadline.bold())
            if let coverage = store.notifications.coverage { Text("Lịch nhắc uống đã xếp đến \(coverage.momiDate), \(coverage.momiTime). Mở Momi trước mốc này để xếp tiếp.").font(.footnote) }
            if store.notifications.truncated { Text("Một số nhắc xa hơn chưa được xếp vì giới hạn hệ thống.").font(.footnote).foregroundStyle(MomiTheme.rose) }
            if let error = store.notifications.lastError { Text(error).font(.footnote).foregroundStyle(.red) }
            if store.notifications.permission != "Đã bật" { Button("Cho phép thông báo") { Task { _ = await store.notifications.requestPermission(); store.refresh() } } }
        }
    }
}
struct DailyIntakeSection: View {
    @Environment(AppStore.self) private var store
    var day: String
    var entries: [IntakeOccurrence] { ScheduleEngine.occurrences(store.snapshot.supplements, day: day) }
    var body: some View {
        if entries.isEmpty { MomiCard { Text("Chưa có lịch uống cho ngày này.").font(.subheadline).foregroundStyle(MomiTheme.muted) } }
        ForEach(entries) { occurrence in IntakeRow(occurrence: occurrence) }
    }
}
struct IntakeRow: View {
    @Environment(AppStore.self) private var store
    var occurrence: IntakeOccurrence
    var log: IntakeLog? { store.snapshot.intakes.first { $0.id == occurrence.id } }
    @State private var time = Date()
    @State private var editingTime = false
    var body: some View {
        MomiCard {
            HStack(alignment: .top) {
                Text(occurrence.scheduledAt.momiTime).font(.subheadline.monospacedDigit().bold())
                VStack(alignment: .leading, spacing: 5) { Text(log?.productName ?? occurrence.name).font(.headline); Text(log?.amount ?? occurrence.amount).font(.subheadline).foregroundStyle(MomiTheme.muted) }
                Spacer(minLength: 0)
            }
            if let log {
                Label(log.status.title + (log.status == .taken ? " · " + log.recordedAt.momiTime : ""), systemImage: log.status == .taken ? "checkmark.circle.fill" : "minus.circle").font(.subheadline).foregroundStyle(MomiTheme.green)
                HStack {
                    Button("Hoàn tác") { _ = store.commit { $0.intakes.removeAll { $0.id == occurrence.id } } }
                    if log.status == .taken { Button("Sửa giờ") { time = log.recordedAt; editingTime = true } }
                }.font(.subheadline)
            } else {
                Text("Chưa ghi nhận").font(.caption).foregroundStyle(MomiTheme.muted)
                if let snooze = store.snapshot.snoozes.first(where: { $0.occurrenceID == occurrence.id }), snooze.until > Date() { Text("Nhắc lại: \(snooze.until.momiDate) · \(snooze.until.momiTime)").font(.caption) }
                HStack {
                    Button("Đã uống") {
                        if occurrence.day == store.today { store.record(occurrence, status: .taken) }
                        else { time = occurrence.scheduledAt; editingTime = true }
                    }.buttonStyle(.borderedProminent)
                    Menu("Tùy chọn") {
                        if occurrence.day == store.today { Button("Nhắc lại sau 15 phút") { store.snooze(occurrence) } }
                        Button("Bỏ qua lần này") { store.record(occurrence, status: .skipped) }
                        Button("Ghi giờ đã uống") { time = min(occurrence.scheduledAt, Date()); editingTime = true }
                    }.buttonStyle(.bordered)
                }
            }
        }.sheet(isPresented: $editingTime) {
            NavigationStack {
                Form { DatePicker("Thời điểm đã uống", selection: $time, in: ...Date()) }
                    .navigationTitle("Ghi giờ uống")
                    .editorToolbar(save: { store.record(occurrence, status: .taken, at: time); editingTime = false }, cancel: { editingTime = false })
            }.presentationDetents([.medium])
        }
    }
}
struct IntakeHistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var date = Date()
    var body: some View {
        MomiPage {
            DatePicker("Ngày muốn xem", selection: $date, in: ...Date(), displayedComponents: .date)
            DailyIntakeSection(day: Day.key(date))
            let currentIDs = Set(ScheduleEngine.occurrences(store.snapshot.supplements, day: Day.key(date)).map(\.id))
            ForEach(store.snapshot.intakes.filter { $0.day == Day.key(date) && !currentIDs.contains($0.id) }) { log in
                MomiCard { Text(log.productName).font(.headline); Text(log.amount); Text(log.status.title + " · " + log.recordedAt.momiTime).font(.subheadline) }
            }
        }.navigationTitle("Lịch sử uống")
    }
}
struct SupplementDetail: View {
    @Environment(AppStore.self) private var store
    var id: UUID
    @State private var editing = false
    var supplement: Supplement? { store.snapshot.supplements.first { $0.id == id } }
    var body: some View {
        if let s = supplement {
            MomiPage {
                MomiCard {
                    Text(s.name).font(.title2.bold())
                    Text(s.instructions.isEmpty ? "Chưa có ghi chú hướng dẫn." : s.instructions).foregroundStyle(MomiTheme.muted)
                    ForEach(s.ingredients) { i in Text("\(i.name) · \(i.amount) \(i.unit)").font(.subheadline) }
                    let shared = s.ingredients.filter { ingredient in store.snapshot.supplements.contains { other in other.id != s.id && other.ingredients.contains { $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == ingredient.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) } } }
                    if !shared.isEmpty { Label("Có thành phần trùng trong sản phẩm khác: " + shared.map(\.name).joined(separator: ", ") + ". Hãy kiểm tra lại lượng dùng.", systemImage: "info.circle").font(.footnote).foregroundStyle(MomiTheme.rose) }
                    Button(s.pauses.contains(where: { $0.through == nil }) ? "Tiếp tục từ bây giờ" : "Tạm dừng từ bây giờ") {
                        _ = store.commit { snapshot in
                            guard let i = snapshot.supplements.firstIndex(where: { $0.id == id }) else { return }
                            if let p = snapshot.supplements[i].pauses.lastIndex(where: { $0.through == nil }) { snapshot.supplements[i].pauses[p].through = Date() }
                            else { snapshot.supplements[i].pauses.append(PausePeriod(from: Date())) }
                            snapshot.snoozes.removeAll { snooze in snapshot.intakes.contains { $0.id == snooze.occurrenceID && $0.supplementID == id } }
                        }
                    }.buttonStyle(.bordered)
                }
                SectionHeading(title: "Các phiên bản lịch dùng")
                ForEach(s.schedules.sorted { $0.effectiveFrom > $1.effectiveFrom }) { p in
                    MomiCard { Text("Từ " + Day.display(p.effectiveFrom)).font(.headline); Text(p.amount + " · " + p.slots.map(\.label).joined(separator: ", ")); Text(p.weekdays.count == 7 ? "Hằng ngày" : "Ngày trong tuần: " + p.weekdays.map { $0 == 1 ? "CN" : "T\($0)" }.joined(separator: ", ")).font(.subheadline); if let end = p.effectiveThrough { Text("Đến " + Day.display(end)).font(.caption) } }
                }
            }.navigationTitle("Sản phẩm").toolbar { Button("Sửa") { editing = true } }
                .sheet(isPresented: $editing) { NavigationStack { SupplementEditor(supplement: s, isNew: false) } }
        } else { EmptyNote(title: "Không tìm thấy sản phẩm") }
    }
}
struct SupplementEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var supplement: Supplement
    var isNew: Bool
    @State private var amount = ""
    @State private var weekdays = Set(1...7)
    @State private var slots = [DoseSlot(hour: 8, minute: 0)]
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(30 * 86400)
    @State private var hasEnd = false
    @State private var reminders = true
    @State private var validation: String?
    var body: some View {
        Form {
            Section("Sản phẩm") { TextField("Tên sản phẩm", text: $supplement.name); TextField("Lượng dùng mỗi lần — theo hướng dẫn", text: $amount); TextField("Hướng dẫn / ghi chú", text: $supplement.instructions, axis: .vertical).lineLimit(2...5) }
            Section("Thành phần trên nhãn · tùy chọn") {
                ForEach($supplement.ingredients) { $ingredient in
                    VStack { TextField("Tên thành phần", text: $ingredient.name); HStack { TextField("Hàm lượng", text: $ingredient.amount); TextField("Đơn vị", text: $ingredient.unit).frame(width: 65) } }
                }.onDelete { supplement.ingredients.remove(atOffsets: $0) }
                Button("Thêm thành phần") { supplement.ingredients.append(Ingredient()) }
            }
            Section("Lịch uống") {
                ForEach(1...7, id: \.self) { day in Toggle(day == 1 ? "Chủ nhật" : "Thứ \(day)", isOn: Binding(get: { weekdays.contains(day) }, set: { if $0 { weekdays.insert(day) } else { weekdays.remove(day) } })) }
                ForEach($slots) { $slot in
                    DatePicker("Giờ uống", selection: Binding(get: { Calendar.current.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: Date())! }, set: { slot.hour = Calendar.current.component(.hour, from: $0); slot.minute = Calendar.current.component(.minute, from: $0) }), displayedComponents: .hourAndMinute)
                }.onDelete { slots.remove(atOffsets: $0) }
                if slots.count < 6 { Button("Thêm giờ uống") { slots.append(DoseSlot(hour: 20, minute: 0)) } }
                DatePicker("Bắt đầu", selection: $start, in: (isNew ? Calendar.current.startOfDay(for: Date()) : Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!))..., displayedComponents: .date)
                Toggle("Có ngày kết thúc", isOn: $hasEnd)
                if hasEnd { DatePicker("Kết thúc", selection: $end, in: start..., displayedComponents: .date) }
                Toggle("Nhắc theo lịch này", isOn: $reminders)
            }
            if !isNew { Section { Text("Lịch sửa bắt đầu từ ngày mai hoặc ngày sau đó. Lịch sử và lượng dùng đã ghi được giữ nguyên. Dùng nút Tạm dừng để dừng nhắc ngay.").font(.footnote) } }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle(isNew ? "Thêm sản phẩm" : "Sửa sản phẩm")
            .onAppear {
                start = isNew ? Date() : Calendar.current.date(byAdding: .day, value: 1, to: Date())!
                if let p = supplement.schedules.sorted(by: { $0.effectiveFrom < $1.effectiveFrom }).last { amount = p.amount; weekdays = Set(p.weekdays); slots = p.slots; reminders = p.notifications; hasEnd = p.effectiveThrough != nil; end = p.effectiveThrough.flatMap { Day.date($0) } ?? end }
            }
            .editorToolbar(save: save, cancel: { dismiss() })
    }
    private func save() {
        guard !supplement.name.trimmingCharacters(in: .whitespaces).isEmpty, !amount.trimmingCharacters(in: .whitespaces).isEmpty, !weekdays.isEmpty, !slots.isEmpty else { validation = "Nhập tên, lượng dùng, ngày và ít nhất một giờ uống."; return }
        guard Set(slots.map(\.label)).count == slots.count else { validation = "Các giờ uống cần khác nhau."; return }
        guard !hasEnd || Day.key(end) >= Day.key(start) else { validation = "Ngày kết thúc cần sau ngày bắt đầu."; return }
        var plan = IntakeSchedule(from: Day.key(start), amount: amount)
        plan.weekdays = weekdays.sorted(); plan.slots = slots; plan.notifications = reminders; plan.effectiveThrough = hasEnd ? Day.key(end) : nil
        do {
            if isNew { supplement.schedules = [plan] }
            else { try ScheduleEngine.replaceFuturePlan(plan, in: &supplement, today: store.today) }
        } catch { validation = error.localizedDescription; return }
        Task {
            if reminders { _ = await store.notifications.requestPermission() }
            if store.commit({ s in s.supplements.removeAll { $0.id == supplement.id }; s.supplements.append(supplement) }) { dismiss() }
        }
    }
}
