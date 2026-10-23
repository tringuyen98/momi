import SwiftUI
import MomiCore

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var quickLog = false
    var upcoming: [Appointment] { store.snapshot.appointments.filter { $0.status == .scheduled && $0.date >= Date() }.sorted { $0.date < $1.date } }
    var tasks: [ChecklistItem] { DashboardChecklist.due(store.snapshot.tasks, on: store.today) }
    var futureTasks: [ChecklistItem] { DashboardChecklist.upcoming(store.snapshot.tasks, after: store.today) }
    var body: some View {
        MomiPage {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month().locale(Locale(identifier: "vi_VN")))).font(.subheadline).foregroundStyle(MomiTheme.muted)
            Text("Chào \(store.snapshot.profile.name.isEmpty ? "bạn" : store.snapshot.profile.name)").font(.largeTitle.bold())
            Label(store.snapshot.profile.stage.title, systemImage: "leaf").font(.subheadline).foregroundStyle(MomiTheme.green)
            if store.snapshot.profile.stage == .preparation {
                NavigationLink { CycleView() } label: { CycleSummaryCard() }.buttonStyle(.plain)
            }
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
                if tasks.isEmpty { Text("Chưa có việc đến hạn hoặc chưa đặt ngày.").foregroundStyle(MomiTheme.muted) }
                ForEach(Array(tasks.prefix(5))) { item in TaskCheckRow(item: item) }
                if tasks.count > 5 { Text("Còn \(tasks.count - 5) việc trong checklist").font(.caption).foregroundStyle(MomiTheme.muted) }
                if !futureTasks.isEmpty {
                    Divider()
                    Text("Việc sắp tới").font(.subheadline.bold())
                    ForEach(Array(futureTasks.prefix(2))) { item in TaskCheckRow(item: item) }
                }
                NavigationLink("Xem checklist (\(tasks.count + futureTasks.count) việc cần làm)") { ChecklistView() }
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
            if store.snapshot.profile.stage == .pregnant { PregnancyJourneyView(changeStage: $changeStage) }
            else {
                MomiCard {
                    Label(store.snapshot.profile.stage.title, systemImage: "leaf").font(.title2.bold()).foregroundStyle(MomiTheme.green)
                    Text("Mỗi bước nhỏ giúp bạn chủ động hơn.").foregroundStyle(MomiTheme.muted)
                    Button("Cập nhật giai đoạn") { changeStage = true }
                }
                MomiCard {
                    NavigationLink { ChecklistView() } label: { RouteRow(title: "Checklist của mẹ", subtitle: "Việc cần chuẩn bị, theo nhịp của bạn", icon: "checklist") }.buttonStyle(.plain)
                    Divider()
                    NavigationLink { NutritionView() } label: { RouteRow(title: "Dinh dưỡng & bổ sung", subtitle: "Món ăn, sản phẩm và lịch uống", icon: "carrot") }.buttonStyle(.plain)
                    Divider()
                    NavigationLink { CycleView() } label: { RouteRow(title: "Lịch kinh & rụng trứng", subtitle: "Ghi kỳ kinh, chỉnh chu kỳ và xem dự báo", icon: "calendar") }.buttonStyle(.plain)
                }
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
