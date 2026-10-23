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
    var body: some View {
        @Bindable var store = store
        ZStack {
            if store.snapshot.profile.onboarded { RootTabView() }
            else { OnboardingView() }
            if store.snapshot.profile.appLock && (!unlocked || scenePhase != .active) {
                VStack(spacing: 22) {
                    Image(systemName: "lock.shield").font(.system(size: 48)).foregroundStyle(MomiTheme.green)
                    Text("Sổ riêng của mẹ").font(.title.bold())
                    if let authMessage { Text(authMessage).font(.subheadline).multilineTextAlignment(.center) }
                    Button("Mở khóa Momi") { Task { await unlock() } }.buttonStyle(.borderedProminent).disabled(unlocking)
                }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(MomiTheme.background)
            }
        }
        .alert("Momi chưa hoàn thành thao tác", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("Đóng") { store.error = nil } } message: { Text(store.error ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { unlocked = false }
            if phase == .active { store.refresh(); if store.snapshot.profile.appLock && !unlocked { Task { await unlock() } } }
        }
        .task { store.refresh(); if store.snapshot.profile.appLock { await unlock() } }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now in
            if scenePhase == .active && store.today != Day.key(now) { store.refresh() }
        }
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
