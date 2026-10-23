import SwiftUI
import MomiCore

struct SupplementsView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    @State private var editingProduct: Supplement?
    @State private var deletingProduct: Supplement?
    var body: some View {
        List {
            Group {
            MomiCard {
                Text("Lịch uống theo thông tin bạn đã nhập").font(.headline)
                Text("Lượng dùng theo nhãn hoặc lời dặn chuyên môn. Momi không tự đề xuất liều.").font(.subheadline).foregroundStyle(MomiTheme.muted)
                NavigationLink("Xem lịch sử uống") { IntakeHistoryView() }
            }
            ReminderCoverageView()
            SectionHeading(title: "Hôm nay")
            DailyIntakeSection(day: store.today)
            Section("Tất cả sản phẩm") {
            ForEach(store.snapshot.supplements) { s in
                MomiCard {
                    HStack(alignment: .top) {
                        NavigationLink { SupplementDetail(id: s.id) } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Label(s.name, systemImage: "pills").font(.headline)
                                if s.pauses.contains(where: { $0.through == nil }) {
                                    Text("Đang tạm dừng").font(.caption).foregroundStyle(MomiTheme.rose)
                                } else if let plan = ScheduleEngine.plan(for: s, day: store.today) {
                                    Text(plan.summary).font(.subheadline).foregroundStyle(MomiTheme.muted)
                                }
                                if let next = s.schedules.filter({ $0.effectiveFrom > store.today }).min(by: { $0.effectiveFrom < $1.effectiveFrom }) {
                                    Text("Từ \(Day.display(next.effectiveFrom)): \(next.summary)").font(.caption).foregroundStyle(MomiTheme.green)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button { editingProduct = s } label: {
                            Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44)
                        }.accessibilityLabel("Sửa \(s.name)")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { deletingProduct = s } label: { Label("Xóa", systemImage: "trash") }.tint(.red)
                }
            }
            }
            if store.snapshot.supplements.isEmpty { EmptyNote(title: "Chưa thêm sản phẩm", message: "Thêm sản phẩm đang dùng để tạo checklist và nhắc hằng ngày.", symbol: "pills") }
            }.listRowBackground(MomiTheme.background).listRowSeparator(.hidden)
        }.listStyle(.plain).scrollContentBackground(.hidden).background(MomiTheme.background)
            .navigationTitle("Vitamin & bổ sung")
            .modifier(SupplementDeletionConfirmation(product: $deletingProduct))
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus").accessibilityLabel("Thêm sản phẩm") } } }
            .sheet(isPresented: $adding) { NavigationStack { SupplementEditor(supplement: Supplement(name: ""), isNew: true) } }
            .sheet(item: $editingProduct) { product in NavigationStack { SupplementEditor(supplement: product, isNew: false) } }
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
    @State private var editingProduct: Supplement?
    var day: String
    var entries: [IntakeOccurrence] { ScheduleEngine.occurrences(store.snapshot.supplements, day: day) }
    private var productIDs: [UUID] {
        entries.reduce(into: []) { ids, entry in
            if !ids.contains(entry.supplementID) { ids.append(entry.supplementID) }
        }
    }
    var body: some View {
        VStack(spacing: 12) {
            if entries.isEmpty {
                MomiCard { Text("Chưa có lịch uống cho ngày này.").font(.subheadline).foregroundStyle(MomiTheme.muted) }
            }
            ForEach(productIDs, id: \.self) { id in
                if let product = store.snapshot.supplements.first(where: { $0.id == id }),
                   let plan = ScheduleEngine.plan(for: product, day: day) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name).font(.headline).foregroundStyle(MomiTheme.ink)
                                Text(plan.summary).font(.subheadline).foregroundStyle(MomiTheme.muted)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Button { editingProduct = product } label: {
                                Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44)
                            }.accessibilityLabel("Sửa lịch uống \(product.name)")
                        }
                        Label(plan.notifications ? "Nhắc: " + plan.slots.sorted { $0.label < $1.label }.map(\.label).joined(separator: " · ") : "Đã tắt nhắc cho lịch này",
                              systemImage: plan.notifications ? "bell" : "bell.slash")
                            .font(.caption).foregroundStyle(MomiTheme.muted)
                        if plan.notifications && day == store.today && store.notifications.permission != "Đã bật" {
                            Text(store.notifications.permission).font(.caption).foregroundStyle(MomiTheme.rose)
                        }
                        if !product.instructions.isEmpty { Text(product.instructions).font(.caption).foregroundStyle(MomiTheme.muted) }
                        if let next = product.schedules.filter({ $0.effectiveFrom > day }).min(by: { $0.effectiveFrom < $1.effectiveFrom }) {
                            Text("Lịch mới từ \(Day.display(next.effectiveFrom)): \(next.summary)")
                                .font(.caption).foregroundStyle(MomiTheme.green)
                        }
                        ForEach(entries.filter { $0.supplementID == id }) { occurrence in
                            Divider()
                            IntakeRow(occurrence: occurrence)
                        }
                    }.padding(14).background(MomiTheme.card, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }.sheet(item: $editingProduct) { product in
            NavigationStack { SupplementEditor(supplement: product, isNew: false) }
        }
    }
}
struct IntakeRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicType
    var occurrence: IntakeOccurrence
    var log: IntakeLog? { store.snapshot.intakes.first { $0.id == occurrence.id } }
    @State private var time = Date()
    @State private var editingTime = false
    var body: some View {
        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            HStack(spacing: 10) {
                Text(occurrence.scheduledAt.momiTime).font(.subheadline.monospacedDigit().bold())
                VStack(alignment: .leading, spacing: 3) {
                    if let log {
                        Text(log.status.title + (log.status == .taken ? " · " + log.recordedAt.momiTime : ""))
                            .foregroundStyle(MomiTheme.green)
                        if log.amount != occurrence.amount { Text(log.amount).foregroundStyle(MomiTheme.muted) }
                    } else {
                        Text("Chưa ghi nhận").foregroundStyle(MomiTheme.muted)
                        if let snooze = store.snapshot.snoozes.first(where: { $0.occurrenceID == occurrence.id }), snooze.until > Date() {
                            Text("Nhắc lại \(snooze.until.momiTime)").foregroundStyle(MomiTheme.green)
                        }
                    }
                }.font(.caption)
            }.frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 2) {
                if log == nil {
                    Button {
                        if occurrence.day == store.today { store.record(occurrence, status: .taken) }
                        else { time = occurrence.scheduledAt; editingTime = true }
                    } label: {
                        Image(systemName: "checkmark").font(.body.bold())
                            .frame(width: 36, height: 36).foregroundStyle(.white)
                            .background(MomiTheme.green, in: Circle()).frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Đánh dấu đã uống \(occurrence.name) lúc \(occurrence.scheduledAt.momiTime)")
                } else {
                    Image(systemName: log?.status == .taken ? "checkmark.circle.fill" : "minus.circle")
                        .foregroundStyle(MomiTheme.green).frame(width: 44, height: 44).accessibilityHidden(true)
                }
                Menu {
                    if let log {
                        Button("Hoàn tác") { _ = store.commit { $0.intakes.removeAll { $0.id == occurrence.id } } }
                        if log.status == .taken { Button("Sửa giờ đã uống") { time = log.recordedAt; editingTime = true } }
                    } else {
                        if occurrence.day == store.today { Button("Nhắc lại sau 15 phút") { store.snooze(occurrence) } }
                        Button("Bỏ qua lần này") { store.record(occurrence, status: .skipped) }
                        Button("Ghi giờ đã uống") { time = min(occurrence.scheduledAt, Date()); editingTime = true }
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Tùy chọn lần uống \(occurrence.scheduledAt.momiTime)")
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
    @Environment(\.dismiss) private var dismiss
    @State private var deletingProduct: Supplement?
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
                Button(role: .destructive) { deletingProduct = s } label: {
                    Label("Xóa sản phẩm", systemImage: "trash").frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.bordered)
                SectionHeading(title: "Các phiên bản lịch dùng")
                ForEach(s.schedules.sorted { $0.effectiveFrom > $1.effectiveFrom }) { p in
                    MomiCard { Text("Từ " + Day.display(p.effectiveFrom)).font(.headline); Text(p.summary + " · " + p.slots.map(\.label).joined(separator: ", ")); Text(p.weekdays.count == 7 ? "Hằng ngày" : "Ngày trong tuần: " + p.weekdays.map { $0 == 1 ? "CN" : "T\($0)" }.joined(separator: ", ")).font(.subheadline); if let end = p.effectiveThrough { Text("Đến " + Day.display(end)).font(.caption) } }
                }
            }.navigationTitle("Sản phẩm").toolbar { Button("Sửa") { editing = true } }
                .modifier(SupplementDeletionConfirmation(product: $deletingProduct, onDeleted: { dismiss() }))
                .sheet(isPresented: $editing) { NavigationStack { SupplementEditor(supplement: s, isNew: false) } }
        } else { EmptyNote(title: "Không tìm thấy sản phẩm") }
    }
}
struct SupplementEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var supplement: Supplement
    var isNew: Bool
    @State private var legacyAmount: String?
    @State private var quantity = ""
    @State private var unit = "viên"
    @State private var showingDates = false
    @State private var showingDetails = false
    @FocusState private var quantityFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var weekdays = Set(1...7)
    @State private var slots = [DoseSlot(hour: 8, minute: 0)]
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(30 * 86400)
    @State private var hasEnd = false
    @State private var reminders = true
    @State private var initialized = false
    @State private var saving = false
    @State private var validation: String?
    @State private var deletingProduct: Supplement?
    private var units: [String] {
        let standard = ["viên", "gói", "ml", "giọt", "muỗng"]
        return standard.contains(unit) ? standard : standard + [unit]
    }
    private var firstAllowedDay: Date {
        let today = Calendar.current.startOfDay(for: Date())
        return isNew ? today : Calendar.current.date(byAdding: .day, value: 1, to: today)!
    }
    private var serving: ServingAmount? {
        guard let value = Double(quantity.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) else { return nil }
        return ServingAmount(quantity: value, unit: unit)
    }
    var body: some View {
        Form {
            Section("Sản phẩm") {
                TextField("Tên sản phẩm, ví dụ: Axit folic", text: $supplement.name)
            }
            Section {
                let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    HStack(spacing: 4) {
                        Button { adjustQuantity(by: -1) } label: {
                            Image(systemName: "minus").frame(width: 44, height: 44)
                        }.buttonStyle(.borderless).disabled((serving?.quantity ?? 0) <= 1)
                            .accessibilityLabel("Giảm số lượng mỗi lần")
                        TextField("Số lượng", text: $quantity)
                            .keyboardType(.decimalPad).multilineTextAlignment(.center)
                            .font(.title3.weight(.semibold)).frame(minWidth: 65)
                            .focused($quantityFocused).accessibilityLabel("Số lượng mỗi lần uống")
                        Button { adjustQuantity(by: 1) } label: {
                            Image(systemName: "plus").frame(width: 44, height: 44)
                        }.buttonStyle(.borderless).accessibilityLabel("Tăng số lượng mỗi lần")
                    }
                    Picker("Đơn vị", selection: $unit) {
                        ForEach(units, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                        .accessibilityLabel("Đơn vị mỗi lần uống")
                }
                if let legacyAmount {
                    Text("Đã lưu trước đây: \(legacyAmount). Nhập lại số lượng mỗi lần để cập nhật lịch.")
                        .font(.caption).foregroundStyle(MomiTheme.muted)
                }
            } header: { Text("Mỗi lần uống") } footer: {
                Text("Nhập theo hướng dẫn đang dùng. Có thể nhập số lẻ như 0,5.")
            }
            Section {
                Stepper("\(slots.count) lần/ngày", value: Binding(get: { slots.count }, set: resizeSlots), in: 1...6)
                ForEach($slots) { $slot in
                    DatePicker("Lần \((slots.firstIndex { $0.id == slot.id } ?? 0) + 1)", selection: Binding(get: {
                        Calendar.current.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: Date())!
                    }, set: {
                        slot.hour = Calendar.current.component(.hour, from: $0)
                        slot.minute = Calendar.current.component(.minute, from: $0)
                    }), displayedComponents: .hourAndMinute)
                }
                Toggle("Nhắc từng lần uống", isOn: $reminders)
            } header: { Text("Uống lúc nào?") } footer: {
                if let serving, serving.isValid {
                    Text("\(serving.label) · \(slots.count) lần/ngày" + (reminders ? " · Nhắc theo từng giờ đã chọn." : " · Không bật thông báo."))
                }
            }
            Section {
                DisclosureGroup(isExpanded: $showingDates) {
                    Toggle("Hằng ngày", isOn: Binding(get: { weekdays.count == 7 }, set: { weekdays = $0 ? Set(1...7) : [] }))
                    if weekdays.count != 7 {
                        ForEach(1...7, id: \.self) { day in
                            Toggle(day == 1 ? "Chủ nhật" : "Thứ \(day)", isOn: Binding(get: { weekdays.contains(day) }, set: {
                                if $0 { weekdays.insert(day) } else { weekdays.remove(day) }
                            }))
                        }
                    }
                    DatePicker(isNew ? "Bắt đầu" : "Lịch mới áp dụng từ", selection: $start, in: firstAllowedDay..., displayedComponents: .date)
                    Toggle("Có ngày kết thúc", isOn: $hasEnd)
                    if hasEnd { DatePicker("Kết thúc", selection: $end, in: start..., displayedComponents: .date) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ngày áp dụng")
                        Text((weekdays.count == 7 ? "Hằng ngày" : "\(weekdays.count) ngày/tuần") + " · Từ \(start.momiDate)" + (hasEnd ? " đến \(end.momiDate)" : ""))
                            .font(.caption).foregroundStyle(MomiTheme.muted)
                    }
                }
            }
            Section {
                DisclosureGroup("Ghi chú & thành phần (tùy chọn)", isExpanded: $showingDetails) {
                    TextField("Ghi chú, ví dụ: sau ăn", text: $supplement.instructions, axis: .vertical).lineLimit(1...3)
                    ForEach($supplement.ingredients) { $ingredient in
                        VStack {
                            TextField("Tên thành phần", text: $ingredient.name)
                            HStack { TextField("Hàm lượng", text: $ingredient.amount); TextField("Đơn vị", text: $ingredient.unit).frame(width: 65) }
                        }
                    }.onDelete { supplement.ingredients.remove(atOffsets: $0) }
                    Button("Thêm thành phần") { supplement.ingredients.append(Ingredient()) }
                }
            }
            if !isNew {
                Section {
                    Text("Sửa trực tiếp, không cần tạm dừng sản phẩm. Lịch mới áp dụng từ \(start.momiDate); các lần uống hôm nay và lịch sử được giữ nguyên.").font(.footnote)
                }
            }
            if !isNew {
                Section {
                    Button(role: .destructive) { deletingProduct = supplement } label: {
                        Label("Xóa sản phẩm", systemImage: "trash")
                    }
                }
            }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle(isNew ? "Thêm sản phẩm" : "Sửa lịch uống")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if quantityFocused {
                        Spacer()
                        Button("Xong") { quantityFocused = false }
                    }
                }
            }
            .onAppear(perform: load)
            .editorToolbar(save: save, cancel: { dismiss() })
            .disabled(saving)
            .modifier(SupplementDeletionConfirmation(product: $deletingProduct, onDeleted: { dismiss() }))
    }
    private func adjustQuantity(by delta: Double) {
        let current = serving?.quantity ?? 0
        let next = current + delta
        guard next.isFinite, next > 0 else { return }
        quantity = next.formatted(.number.locale(Locale(identifier: "vi_VN")).grouping(.never))
    }
    private func resizeSlots(_ count: Int) {
        if count < slots.count { slots = Array(slots.prefix(count)) }
        else {
            for hour in [8, 12, 18, 20, 10, 15, 7, 21] where slots.count < count {
                if !slots.contains(where: { $0.hour == hour && $0.minute == 0 }) { slots.append(DoseSlot(hour: hour, minute: 0)) }
            }
        }
        slots.sort { $0.label < $1.label }
    }
    private func load() {
        guard !initialized else { return }
        initialized = true
        start = firstAllowedDay
        if let p = supplement.schedules.max(by: { $0.effectiveFrom < $1.effectiveFrom }) {
            if let serving = p.serving {
                quantity = serving.quantity.formatted(.number.locale(Locale(identifier: "vi_VN")).grouping(.never))
                unit = serving.unit
            } else { legacyAmount = p.amount }
            weekdays = Set(p.weekdays)
            slots = p.slots.sorted { $0.label < $1.label }
            if slots.isEmpty { slots = [DoseSlot(hour: 8, minute: 0)] }
            reminders = p.notifications
            start = max(firstAllowedDay, Day.date(p.effectiveFrom) ?? firstAllowedDay)
            hasEnd = p.effectiveThrough != nil
            end = max(start, p.effectiveThrough.flatMap { Day.date($0) } ?? end)
        }
    }
    private func save() {
        guard !saving else { return }
        supplement.name = supplement.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !supplement.name.isEmpty, !weekdays.isEmpty, !slots.isEmpty else { validation = "Nhập tên, ngày và ít nhất một giờ uống."; return }
        guard Set(slots.map(\.label)).count == slots.count else { validation = "Các giờ uống cần khác nhau."; return }
        guard !hasEnd || Day.key(end) >= Day.key(start) else { validation = "Ngày kết thúc cần sau ngày bắt đầu."; return }
        guard let dose = serving, dose.isValid else {
            validation = "Nhập số lượng lớn hơn 0 cho mỗi lần uống."
            quantityFocused = true
            return
        }
        quantityFocused = false
        var plan = IntakeSchedule(from: Day.key(start), amount: dose.label)
        plan.serving = dose
        plan.weekdays = weekdays.sorted(); plan.slots = slots.sorted { $0.label < $1.label }
        plan.notifications = reminders; plan.effectiveThrough = hasEnd ? Day.key(end) : nil
        var updated = supplement
        do {
            if isNew { updated.schedules = [plan] }
            else { try ScheduleEngine.replaceFuturePlan(plan, in: &updated, today: Day.key(Date())) }
        } catch { validation = error.localizedDescription; return }
        saving = true
        Task {
            if reminders { _ = await store.notifications.requestPermission() }
            if store.commit({ s in s.supplements.removeAll { $0.id == updated.id }; s.supplements.append(updated) }) { dismiss() }
            saving = false
        }
    }
}

private struct SupplementDeletionConfirmation: ViewModifier {
    @Environment(AppStore.self) private var store
    @Binding var product: Supplement?
    var onDeleted: () -> Void = {}

    func body(content: Content) -> some View {
        content.alert("Xóa sản phẩm?", isPresented: Binding(get: { product != nil }, set: { if !$0 { product = nil } }), presenting: product) { item in
            Button("Hủy", role: .cancel) { product = nil }
            Button("Xóa sản phẩm", role: .destructive) {
                if store.commit({ SupplementManagement.remove(item.id, from: &$0) }) {
                    store.files.cleanup(keeping: store.snapshot)
                    product = nil
                    onDeleted()
                }
            }
        } message: { item in
            Text("Xóa \(item.name) và các nhắc uống còn lại. Lịch sử đã ghi vẫn được giữ nguyên.")
        }
    }
}
