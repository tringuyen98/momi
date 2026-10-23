import SwiftUI
import MomiCore

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var stage: Stage = .preparation
    @State private var hasDate = false
    @State private var date = Date()
    var body: some View {
        NavigationStack {
            MomiPage {
                Image(systemName: "leaf.circle.fill").font(.system(size: 70)).foregroundStyle(MomiTheme.green).padding(.top, 32).accessibilityHidden(true)
                Text("Chào bạn, cùng chuẩn bị từng chút một").font(.largeTitle.bold())
                Text("Momi giúp bạn nhớ việc cần làm, lịch hẹn và vitamin — để bạn bớt phải ghi nhớ.").foregroundStyle(MomiTheme.muted)
                MomiCard {
                    Text("Bạn muốn Momi gọi mình là gì?").font(.headline)
                    TextField("Tên của bạn", text: $name).textFieldStyle(.roundedBorder)
                    Picker("Giai đoạn", selection: $stage) { ForEach(Stage.allCases, id: \.self) { Text($0.title).tag($0) } }
                    Toggle(stage == .pregnant ? "Đã biết ngày dự sinh" : "Ghi ngày bắt đầu kỳ kinh gần nhất", isOn: $hasDate)
                    if hasDate { DatePicker(stage == .pregnant ? "Ngày dự sinh" : "Ngày bắt đầu", selection: $date, displayedComponents: .date) }
                }
                Label("Không cần tài khoản. Thông tin chưa biết có thể thêm sau.", systemImage: "lock").font(.footnote).foregroundStyle(MomiTheme.muted)
                PrimaryButton(title: "Bắt đầu cùng Momi") {
                    _ = store.commit { s in
                        s.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        s.profile.stage = stage; s.profile.onboarded = true
                        if hasDate && stage == .pregnant { s.profile.dueDate = Day.key(date) }
                        if hasDate && stage == .preparation { var log = DailyHealthLog(day: Day.key(date)); log.bleeding = true; log.periodStart = true; s.dailyLogs.append(log) }
                    }
                }
            }
        }
    }
}

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var quickLog = false
    var upcoming: [Appointment] { store.snapshot.appointments.filter { $0.status == .scheduled && $0.date >= Date() }.sorted { $0.date < $1.date } }
    var tasks: [ChecklistItem] { store.snapshot.tasks.filter { $0.status == .todo && $0.dueDay.map { $0 <= store.today } == true } }
    var body: some View {
        MomiPage {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month().locale(Locale(identifier: "vi_VN")))).font(.subheadline).foregroundStyle(MomiTheme.muted)
            Text("Chào \(store.snapshot.profile.name.isEmpty ? "bạn" : store.snapshot.profile.name)").font(.largeTitle.bold())
            Label(store.snapshot.profile.stage.title, systemImage: "leaf").font(.subheadline).foregroundStyle(MomiTheme.green)
            SectionHeading(title: "Sắp tới")
            if let a = upcoming.first {
                NavigationLink { AppointmentDetail(id: a.id) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(a.kind.title, systemImage: "calendar").font(.caption)
                        Text(a.title).font(.title3.bold())
                        Text(a.date.momiDate + " · " + a.date.momiTime)
                        if !a.place.isEmpty { Label(a.place, systemImage: "mappin.and.ellipse") }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(20).foregroundStyle(.white).background(MomiTheme.green, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            } else { MomiCard { Text("Hôm nay chưa có lịch hẹn."); NavigationLink("Thêm lịch khi bạn cần") { AppointmentsView() } } }
            HStack { SectionHeading(title: "Vitamin hôm nay"); Spacer(); NavigationLink("Lịch uống") { SupplementsView() }.font(.subheadline) }
            DailyIntakeSection(day: store.today)
            SectionHeading(title: "Việc hôm nay")
            MomiCard {
                if tasks.isEmpty { Text("Chưa có việc đến hạn. Bạn có thể thêm khi cần.").foregroundStyle(MomiTheme.muted) }
                ForEach(Array(tasks.prefix(3))) { item in TaskCheckRow(item: item) }
                NavigationLink("Xem checklist") { ChecklistView() }
            }
            Button { quickLog = true } label: { RouteRow(title: "Hôm nay bạn thế nào?", subtitle: "Ghi vài điều, hoặc để sau", icon: "heart") }.buttonStyle(.plain)
            if let article = ContentLibrary.articles.first {
                NavigationLink { ArticleDetail(article: article) } label: { MomiCard { Label("Một chút kiến thức", systemImage: "book").font(.caption).foregroundStyle(MomiTheme.green); Text(article.title).font(.headline); Text(article.summary).font(.subheadline).foregroundStyle(MomiTheme.muted) } }.buttonStyle(.plain)
            }
        }.toolbar { ToolbarItem(placement: .primaryAction) { NavigationLink { SettingsView() } label: { Image(systemName: "gearshape").accessibilityLabel("Cài đặt") } } }
            .sheet(isPresented: $quickLog) { NavigationStack { DailyLogEditor(day: store.today) } }
    }
}

struct JourneyView: View {
    @Environment(AppStore.self) private var store
    @State private var changeStage = false
    var body: some View {
        MomiPage {
            MomiCard {
                Label(store.snapshot.profile.stage.title, systemImage: "leaf").font(.title2.bold()).foregroundStyle(MomiTheme.green)
                if store.snapshot.profile.stage == .pregnant {
                    if let key = store.snapshot.profile.dueDate, let date = Day.date(key) {
                        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
                        let age = 280 - days
                        if age >= 0 && age <= 301 { Text("Khoảng \(age / 7) tuần \(age % 7) ngày").font(.title.bold()) }
                        Text("Dự sinh: " + Day.display(key)).foregroundStyle(MomiTheme.muted)
                        Text("Tính theo ngày dự sinh bạn nhập; cập nhật theo thông tin bác sĩ.").font(.footnote)
                    } else { Text("Bạn có thể bổ sung ngày dự sinh sau.") }
                } else { Text("Mỗi bước nhỏ giúp bạn chủ động hơn.").foregroundStyle(MomiTheme.muted) }
                Button("Cập nhật giai đoạn") { changeStage = true }
            }
            MomiCard {
                NavigationLink { ChecklistView() } label: { RouteRow(title: "Checklist của mẹ", subtitle: "Việc cần chuẩn bị, theo nhịp của bạn", icon: "checklist") }.buttonStyle(.plain)
                Divider()
                NavigationLink { NutritionView() } label: { RouteRow(title: "Dinh dưỡng & bổ sung", subtitle: "Món ăn, sản phẩm và lịch uống", icon: "carrot") }.buttonStyle(.plain)
                Divider()
                NavigationLink { CycleView() } label: { RouteRow(title: "Chu kỳ & cảm nhận", subtitle: "Xem lại những gì đã ghi", icon: "drop") }.buttonStyle(.plain)
            }
            if !store.snapshot.profile.stageHistory.isEmpty {
                SectionHeading(title: "Các mốc đã ghi")
                ForEach(store.snapshot.profile.stageHistory, id: \.self) { Text($0).font(.subheadline).foregroundStyle(MomiTheme.muted) }
            }
        }.navigationTitle("Hành trình").sheet(isPresented: $changeStage) { NavigationStack { StageEditor() } }
    }
}

struct StageEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .preparation
    @State private var due = Date()
    @State private var hasDate = false
    var body: some View {
        Form {
            Picker("Giai đoạn", selection: $stage) { ForEach(Stage.allCases, id: \.self) { Text($0.title).tag($0) } }
            if stage == .pregnant { Toggle("Đã biết ngày dự sinh", isOn: $hasDate); if hasDate { DatePicker("Ngày dự sinh", selection: $due, displayedComponents: .date) } }
            Section("Xem lại lịch đang dùng") {
                Text("Lịch uống và lịch hẹn hiện tại được giữ nguyên. Hãy trao đổi và điều chỉnh khi cần; Momi không tự thay đổi lịch theo giai đoạn.").font(.subheadline)
                Text("\(store.snapshot.supplements.count) sản phẩm · \(store.snapshot.appointments.filter { $0.status == .scheduled }.count) lịch hẹn")
            }
        }.momiForm().navigationTitle("Cập nhật giai đoạn")
            .onAppear { stage = store.snapshot.profile.stage; hasDate = store.snapshot.profile.dueDate != nil; due = store.snapshot.profile.dueDate.flatMap { Day.date($0) } ?? Date() }
            .editorToolbar(save: {
                if store.commit({ s in
                    if s.profile.stage != stage { s.profile.stageHistory.append(Day.display(store.today) + " — " + stage.title) }
                    s.profile.stage = stage; s.profile.dueDate = stage == .pregnant && hasDate ? Day.key(due) : nil
                }) { dismiss() }
            }, cancel: { dismiss() })
    }
}
