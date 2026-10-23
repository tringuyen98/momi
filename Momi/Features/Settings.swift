import SwiftUI
import LocalAuthentication
import MomiCore
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var message: String?
    @State private var authenticating = false
    @State private var requestingNotifications = false
    @State private var rename = false
    @State private var name = ""

    var body: some View {
        Form {
            Section {
                Button {
                    name = store.snapshot.profile.name
                    rename = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44, weight: .light)).foregroundStyle(MomiTheme.green)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.snapshot.profile.name.isEmpty ? "Tên của bạn" : store.snapshot.profile.name)
                                .font(.title3.weight(.semibold)).foregroundStyle(MomiTheme.ink)
                            Text("Momi gọi bạn bằng tên này").font(.caption).foregroundStyle(MomiTheme.muted)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "pencil").foregroundStyle(MomiTheme.green).accessibilityHidden(true)
                    }.padding(.vertical, 8).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityHint("Chạm để đổi tên")
            }.listRowBackground(MomiTheme.card)
            Section("Hành trình của bạn") {
                NavigationLink { StageEditor() } label: {
                    settingsLabel("Giai đoạn", subtitle: store.snapshot.profile.stage.title, icon: "leaf", color: MomiTheme.green)
                }
                if store.snapshot.profile.stage == .preparation {
                    NavigationLink { CycleView() } label: {
                        settingsLabel("Kỳ kinh & chu kỳ", subtitle: "Cập nhật ngày và độ dài chu kỳ", icon: "calendar", color: MomiTheme.rose)
                    }
                }
            }.listRowBackground(MomiTheme.card)
            Section("Tùy chọn") {
                Button(action: configureNotifications) {
                    HStack(spacing: 10) {
                        settingsLabel("Thông báo", subtitle: notificationSubtitle, icon: "bell", color: MomiTheme.green)
                        Spacer(minLength: 0)
                        if requestingNotifications { ProgressView() }
                        else { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(MomiTheme.muted).accessibilityHidden(true) }
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(requestingNotifications || store.notifications.permission == "Chưa kiểm tra")
                Toggle(isOn: Binding(get: { store.snapshot.profile.appLock }, set: { enabled in
                    authenticating = true
                    Task {
                        defer { authenticating = false }
                        do {
                            let allowed = try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Thay đổi khóa bảo vệ Momi")
                            if allowed { _ = store.commit { $0.profile.appLock = enabled } }
                        } catch { message = "Chưa xác thực được. Cài đặt khóa không thay đổi." }
                    }
                })) {
                    settingsLabel("Khóa Momi", subtitle: "Face ID, Touch ID hoặc mật mã", icon: "lock", color: MomiTheme.green)
                }.disabled(authenticating).tint(MomiTheme.green)
            }.listRowBackground(MomiTheme.card)
        }.momiForm().navigationTitle("Cài đặt").navigationBarTitleDisplayMode(.inline)
            .task { await store.notifications.readPermission() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await store.notifications.readPermission() } }
            }
            .alert("Đổi tên", isPresented: $rename) {
                TextField("Tên", text: $name)
                Button("Hủy", role: .cancel) {}
                Button("Lưu") { _ = store.commit { $0.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines) } }
            }
            .alert("Chưa đổi được khóa app", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("Đóng", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
    }
    private var notificationSubtitle: String {
        switch store.notifications.permission {
        case "Đã bật": "Đang bật · Điều chỉnh trên iPhone"
        case "Chưa cấp quyền": "Bật nhắc lịch uống và lịch hẹn"
        case "Chưa kiểm tra": "Đang kiểm tra…"
        default: "Đang tắt · Bật trong Cài đặt iPhone"
        }
    }
    private func configureNotifications() {
        if store.notifications.permission == "Chưa cấp quyền" {
            requestingNotifications = true
            Task {
                _ = await store.notifications.requestPermission()
                store.refresh()
                requestingNotifications = false
            }
        } else {
            #if os(iOS)
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            #endif
        }
    }
    private func settingsLabel(_ title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body.weight(.medium)).foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body).foregroundStyle(MomiTheme.ink)
                Text(subtitle).font(.caption).foregroundStyle(MomiTheme.muted)
            }.fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 5)
    }

}
