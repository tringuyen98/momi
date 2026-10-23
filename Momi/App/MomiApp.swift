import SwiftUI
import LocalAuthentication
import Combine
import MomiCore

@main struct MomiApp: App {
    @State private var store: AppStore?
    @State private var startupError: String?
    init() {
        do { _store = State(initialValue: try AppStore(persistence: Persistence(), files: AttachmentService())) }
        catch { _startupError = State(initialValue: error.localizedDescription) }
    }
    var body: some Scene {
        WindowGroup {
            if let store { AppRootView().environment(store).tint(MomiTheme.green).environment(\.locale, Locale(identifier: "vi_VN")).preferredColorScheme(.light) }
            else { ContentUnavailableView("Chưa mở được dữ liệu", systemImage: "externaldrive.badge.exclamationmark", description: Text(startupError ?? "Hãy thử mở lại app. Dữ liệu cũ chưa bị thay đổi.")) }
        }
    }
}

struct AppRootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlocked = false
    @State private var unlocking = false
    @State private var authMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entering = false
    @State private var homeReady = false
    @State private var homeSettled = false
    @State private var entranceCount = 0
    @State private var welcomeName = ""
    var body: some View {
        @Bindable var store = store
        ZStack {
            if (store.snapshot.profile.onboarded && !store.previewWelcome && !entering) || (entering && homeReady) {
                RootTabView()
                    .scaleEffect(entering && !homeSettled && !reduceMotion ? 0.97 : 1)
                    .blur(radius: entering && !homeSettled && !reduceMotion ? 5 : 0)
                    .allowsHitTesting(!entering)
                    .accessibilityHidden(entering)
            } else {
                OnboardingView(isPreview: store.previewWelcome, onClose: { store.previewWelcome = false }, onBegin: begin)
                    .allowsHitTesting(!entering).accessibilityHidden(entering)
            }
            if entering {
                MomiEntranceOverlay(name: welcomeName, onCovered: { homeReady = true }, onReveal: {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.65, dampingFraction: 0.9)) { homeSettled = true }
                }, onFinished: finishEntrance).zIndex(2)
            }
            if store.snapshot.profile.appLock && (!unlocked || scenePhase != .active) {
                VStack(spacing: 22) {
                    Image(systemName: "lock.shield").font(.system(size: 48)).foregroundStyle(MomiTheme.green)
                    Text("Sổ riêng của mẹ").font(.title.bold())
                    if let authMessage { Text(authMessage).font(.subheadline).multilineTextAlignment(.center) }
                    Button("Mở khóa Momi") { Task { await unlock() } }.buttonStyle(.borderedProminent).disabled(unlocking)
                }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(MomiTheme.background).zIndex(3)
            }
        }
        .alert("Momi chưa hoàn thành thao tác", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Đóng") { store.error = nil } } message: { Text(store.error ?? "") }
        .sensoryFeedback(.success, trigger: entranceCount)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && entering { finishEntrance() }
            if phase == .background { unlocked = false }
            if phase == .active { store.refresh(); if store.snapshot.profile.appLock && !unlocked { Task { await unlock() } } }
        }
        .task { store.refresh(); if store.snapshot.profile.appLock { await unlock() } }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now in
            if scenePhase == .active && store.today != Day.key(now) { store.refresh() }
        }
    }
    private func begin(_ draft: OnboardingDraft) -> Bool {
        guard !entering else { return false }
        if !store.previewWelcome {
            guard store.commit({ s in
                s.profile.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                s.profile.stage = draft.stage; s.profile.onboarded = true
                s.profile.dueDate = draft.stage == .pregnant && draft.hasDueDate ? Day.key(draft.dueDate) : nil
                if draft.stage == .preparation && draft.hasPeriodDate {
                    let day = Day.key(min(draft.periodDate, Date()))
                    var log = s.dailyLogs.first { $0.day == day } ?? DailyHealthLog(day: day)
                    log.bleeding = true; log.periodStart = true
                    s.dailyLogs.removeAll { $0.day == day }; s.dailyLogs.append(log)
                }
            }) else { return false }
        }
        welcomeName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.selectedTab = 0
        homeReady = false; homeSettled = false; entering = true; entranceCount += 1
        return true
    }
    private func finishEntrance() {
        store.previewWelcome = false
        entering = false; homeReady = false; homeSettled = true
    }
    private func unlock() async {
        guard !unlocking else { return }
        unlocking = true; defer { unlocking = false }
        do { unlocked = try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Mở sổ sức khỏe của bạn trong Momi"); authMessage = nil }
        catch { authMessage = "Bạn có thể thử lại bằng Face ID hoặc mật mã thiết bị." }
    }
}
struct RootTabView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            NavigationStack { TodayView() }.tabItem { Label("Hôm nay", systemImage: "sun.max") }.tag(0)
            NavigationStack { JourneyView() }.tabItem { Label("Hành trình", systemImage: "leaf") }.tag(1)
            NavigationStack { KnowledgeView() }.tabItem { Label("Kiến thức", systemImage: "book") }.tag(2)
            NavigationStack { MotherBookView() }.tabItem { Label("Sổ của mẹ", systemImage: "heart.text.square") }.tag(3)
        }
        .sheet(item: $store.route) { route in NavigationStack { RouteDestination(route: route).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { store.route = nil } } } } }
    }
}
struct RouteDestination: View {
    var route: Route
    var body: some View {
        switch route {
        case .checklist: ChecklistView()
        case .supplements: SupplementsView()
        case .intakeHistory: IntakeHistoryView()
        case .appointments: AppointmentsView()
        case .vaccines: VaccinesView()
        case .cycle: CycleView()
        case .nutrition: NutritionView()
        case .ultrasounds: UltrasoundsView()
        case .records: RecordsView()
        case .journal: JournalView()
        case .settings: SettingsView()
        }
    }
}
struct MotherBookView: View {
    var body: some View {
        MomiPage {
            MomiCard {
                row(.vaccines, "Phiếu tiêm, các mũi đã ghi nhận", "syringe")
                Divider(); row(.appointments, "Lịch khám và những việc cần nhớ", "calendar")
                Divider(); row(.ultrasounds, "Lưu ảnh và ghi chú theo tuần thai", "photo.on.rectangle")
                Divider(); row(.records, "Giấy khám, kết quả, lời dặn", "folder")
                Divider(); row(.supplements, "Sản phẩm và lịch uống", "pills")
                Divider(); row(.journal, "Vài dòng dành cho riêng bạn", "square.and.pencil")
            }
            Text("Lưu trên thiết bị. Bạn có thể xuất backup được mã hóa trong Cài đặt.").font(.footnote).foregroundStyle(MomiTheme.muted)
        }.navigationTitle("Sổ của mẹ")
    }
    private func row(_ route: Route, _ subtitle: String, _ icon: String) -> some View {
        NavigationLink { RouteDestination(route: route) } label: { RouteRow(title: route.title, subtitle: subtitle, icon: icon) }.buttonStyle(.plain)
    }
}
