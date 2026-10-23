import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication
import MomiCore
#if os(iOS)
import UIKit
#endif

struct MomiBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var password = ""
    @State private var busy = false
    @State private var message: String?
    @State private var importing = false
    @State private var exporting = false
    @State private var exportDocument: MomiBackupDocument?
    @State private var exportType: UTType = .data
    @State private var exportName = "Momi.momi"
    @State private var exportedBackup = true
    @State private var pendingRestore: BackupPayload?
    @State private var confirmRestore = false
    @State private var confirmDelete = false
    @State private var confirmPhrase = ""
    @State private var rename = false
    @State private var name = ""
    var body: some View {
        Form {
            Section("Của bạn") {
                Button("Tên: " + (store.snapshot.profile.name.isEmpty ? "Chưa đặt" : store.snapshot.profile.name)) { name = store.snapshot.profile.name; rename = true }
                NavigationLink("Giai đoạn: " + store.snapshot.profile.stage.title) { StageEditor() }
                if store.snapshot.profile.stage == .preparation { NavigationLink("Kỳ kinh & thiết lập chu kỳ") { CycleView() } }
                Text("Dữ liệu lưu trên thiết bị, không có tài khoản hoặc máy chủ Momi.").font(.footnote)
            }
            Section("Thông báo") {
                Text(store.notifications.permission)
                Toggle("Ẩn nội dung nhạy cảm", isOn: Binding(get: { store.snapshot.profile.hideNotificationDetails }, set: { value in _ = store.commit { $0.profile.hideNotificationDetails = value } }))
                Button("Yêu cầu quyền thông báo") { Task { _ = await store.notifications.requestPermission(); store.refresh() } }
                #if os(iOS)
                Button("Mở Cài đặt iPhone") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
                #endif
                if let coverage = store.notifications.coverage { Text("Nhắc uống đã xếp đến \(coverage.momiDate) · \(coverage.momiTime). Mở app trước mốc này để xếp tiếp.").font(.footnote) }
            }
            Section("Quyền riêng tư") {
                Toggle("Khóa app bằng xác thực thiết bị", isOn: Binding(get: { store.snapshot.profile.appLock }, set: { enabled in
                    Task {
                        do {
                            let allowed = try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Thay đổi khóa bảo vệ Momi")
                            if allowed { _ = store.commit { $0.profile.appLock = enabled } }
                        } catch { message = "Chưa xác thực được. Cài đặt khóa không thay đổi." }
                    }
                }))
                Text("Momi dùng cơ chế bảo vệ dữ liệu của thiết bị. Bản backup xuất ra được mã hóa bằng mật khẩu riêng.").font(.footnote)
            }
            Section("Sao lưu & khôi phục") {
                SecureField("Mật khẩu backup · ít nhất 10 ký tự", text: $password)
                Text("Giữ mật khẩu ở nơi an toàn; Momi không có cách khôi phục mật khẩu. Backup gồm hồ sơ và ảnh/PDF. Đồng bộ iCloud tự động chưa bật trong bản này.").font(.footnote)
                Button("Tạo và lưu backup mã hóa") { Task { await exportBackup() } }.disabled(busy || password.count < 10)
                Button("Chọn backup để khôi phục") { importing = true }.disabled(busy || password.isEmpty)
                if busy { ProgressView("Đang xử lý…") }
                if let message { Text(message).font(.footnote) }
            }
            Section("Quản lý dữ liệu") {
                Text("\(store.snapshot.attachments.count) file · \(store.snapshot.intakes.count) bản ghi uống · \(store.snapshot.vaccinations.count) mũi tiêm · \(store.snapshot.ultrasounds.count) lần siêu âm").font(.footnote)
                Button("Xuất lịch uống CSV") {
                    exportDocument = MomiBackupDocument(data: Data(DataExport.intakeCSV(store.snapshot).utf8)); exportType = .commaSeparatedText; exportName = "Momi-lich-uong.csv"; exportedBackup = false; exporting = true
                }
                #if os(iOS)
                Button("Xuất tóm tắt đi khám PDF") {
                    exportDocument = MomiBackupDocument(data: PDFExport.summary(store.snapshot)); exportType = .pdf; exportName = "Momi-tom-tat.pdf"; exportedBackup = false; exporting = true
                }
                #endif
                Text("PDF và CSV là bản đọc được để bạn chia sẻ; không được mã hóa và không dùng để khôi phục app.").font(.footnote)
                Button("Xóa dữ liệu trên thiết bị", role: .destructive) { confirmPhrase = ""; confirmDelete = true }
            }
            Section { Text("Momi 0.1 · Bản phát triển cá nhân\nOCR là bản nháp cần kiểm tra. Nội dung kiến thức chưa được duyệt riêng bởi bác sĩ Việt Nam.").font(.footnote).foregroundStyle(MomiTheme.muted) }
        }.momiForm().navigationTitle("Cài đặt")
            .alert("Đổi tên", isPresented: $rename) { TextField("Tên", text: $name); Button("Hủy", role: .cancel) {}; Button("Lưu") { _ = store.commit { $0.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines) } } }
            .alert("Thay dữ liệu bằng backup?", isPresented: $confirmRestore) {
                Button("Hủy", role: .cancel) { pendingRestore = nil }
                Button("Khôi phục", role: .destructive) {
                    guard let payload = pendingRestore else { return }
                    do { try store.restore(payload); message = "Đã khôi phục dữ liệu và xếp lại lời nhắc."; pendingRestore = nil; password = "" }
                    catch { message = error.localizedDescription }
                }
            } message: { Text("Backup đã giải mã và kiểm tra. Dữ liệu hiện tại sẽ được thay thế. Nên xuất backup hiện tại trước khi tiếp tục.") }
            .alert("Xóa dữ liệu Momi?", isPresented: $confirmDelete) {
                TextField("Nhập XOA để xác nhận", text: $confirmPhrase)
                Button("Hủy", role: .cancel) {}
                Button("Xóa dữ liệu", role: .destructive) {
                    guard confirmPhrase == "XOA" else { message = "Chưa xác nhận. Dữ liệu được giữ nguyên."; return }
                    if store.commit({ $0 = Snapshot() }) { store.files.cleanup(keeping: store.snapshot) }
                }
            } message: { Text("Xóa hồ sơ, ảnh và lịch nhắc trên máy. File backup bạn đã xuất ra Files không bị xóa.") }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: exportType, defaultFilename: exportName) { result in
                switch result { case .success: message = exportedBackup ? "Đã lưu file backup tại vị trí bạn chọn." : "Đã xuất file tại vị trí bạn chọn."; password = ""; case .failure(let error): message = "Chưa lưu file: " + error.localizedDescription }
                exportDocument = nil
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .item]) { result in
                Task {
                    busy = true; defer { busy = false }
                    do { let url = try result.get(); pendingRestore = try await store.readBackup(url, password: password); confirmRestore = true }
                    catch { message = "Không mở được backup. Kiểm tra mật khẩu và file. " + error.localizedDescription }
                }
            }
    }
    private func exportBackup() async {
        busy = true; message = nil; defer { busy = false }
        do {
            let url = try await store.makeBackup(password: password)
            exportDocument = MomiBackupDocument(data: try Data(contentsOf: url))
            try? FileManager.default.removeItem(at: url)
            exportType = .data; exportName = "Momi-\(store.today).momi"; exportedBackup = true
            exporting = true
        } catch { message = "Chưa tạo được backup: " + error.localizedDescription }
    }
}
