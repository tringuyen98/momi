import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import QuickLook
import MomiCore
#if os(iOS)
import VisionKit
#endif

struct VaccinesView: View {
    @Environment(AppStore.self) private var store
    @State private var importing = false
    @State private var manual = false
    @State private var addingName = false
    @State private var name = ""
    var body: some View {
        MomiPage {
            MomiCard {
                Text("Giữ lại lịch sử tiêm của bạn").font(.title3.bold())
                Text("Chụp phiếu tiêm, kiểm tra thông tin và lưu lịch hẹn đã được xác nhận.").foregroundStyle(MomiTheme.muted)
                PrimaryButton(title: "Chụp / tải phiếu tiêm") { importing = true }
                Button("Nhập mũi đã tiêm bằng tay") { manual = true }
                Button("Thêm vaccine cần trao đổi") { addingName = true }
            }
            ForEach(store.snapshot.vaccines) { vaccine in
                NavigationLink { VaccineDetail(id: vaccine.id) } label: {
                    MomiCard {
                        Label(vaccine.name, systemImage: "syringe").font(.headline)
                        let count = store.snapshot.vaccinations.filter { $0.vaccineID == vaccine.id }.count
                        Text(count == 0 ? "Chưa có mũi tiêm được ghi nhận" : "\(count) mũi đã ghi nhận").font(.subheadline).foregroundStyle(MomiTheme.muted)
                        if let next = store.snapshot.appointments.filter({ $0.vaccineID == vaccine.id && $0.status == .scheduled }).sorted(by: { $0.date < $1.date }).first { Text("Lịch hẹn: " + next.date.momiDate).font(.caption).foregroundStyle(MomiTheme.green) }
                    }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Vaccine")
            .sheet(isPresented: $importing) { NavigationStack { VaccineImportView() } }
            .sheet(isPresented: $manual) { NavigationStack { VaccinationEditor() } }
            .alert("Vaccine cần trao đổi", isPresented: $addingName) { TextField("Tên vaccine", text: $name); Button("Hủy", role: .cancel) {}; Button("Thêm") { let trimmed = name.trimmingCharacters(in: .whitespaces); if !trimmed.isEmpty { _ = store.commit { $0.vaccines.append(VaccineRecord(name: trimmed)) }; name = "" } } }
    }
}
struct VaccineDetail: View {
    @Environment(AppStore.self) private var store
    var id: UUID
    @State private var adding = false
    @State private var appointment = false
    @State private var preview: URL?
    @State private var editingDose: VaccinationDose?
    @State private var editingName = false
    @State private var name = ""
    var body: some View {
        if let vaccine = store.snapshot.vaccines.first(where: { $0.id == id }) {
            MomiPage {
                MomiCard { Text(vaccine.name).font(.title2.bold()); Text(vaccine.notes); Button("Ghi nhận mũi đã tiêm") { adding = true }; Button("Thêm lịch hẹn đã xác nhận") { appointment = true } }
                ForEach(store.snapshot.appointments.filter { $0.vaccineID == id && $0.status == .scheduled }) { a in
                    NavigationLink { AppointmentDetail(id: a.id) } label: { MomiCard { Text(a.title).font(.headline); Text(a.date.momiDate + " · " + a.date.momiTime) } }.buttonStyle(.plain)
                }
                SectionHeading(title: "Các mũi đã ghi nhận")
                ForEach(store.snapshot.vaccinations.filter { $0.vaccineID == id }.sorted { $0.day > $1.day }) { dose in
                    MomiCard {
                        HStack { Text(dose.number.map { "Mũi \($0)" } ?? "Chưa ghi số mũi").font(.headline); Spacer(); Button("Sửa") { editingDose = dose } }
                        Text(Day.display(dose.day)); if !dose.place.isEmpty { Text(dose.place) }
                        if !dose.product.isEmpty { Text(dose.product) }; if !dose.lot.isEmpty { Text("Số lô: " + dose.lot).font(.caption) }
                        if !dose.notes.isEmpty { Text(dose.notes).font(.subheadline) }
                        AttachmentLinks(ids: dose.attachmentIDs)
                    }
                }
            }.navigationTitle("Hồ sơ vaccine")
                .toolbar { Button("Đổi tên") { name = vaccine.name; editingName = true } }
                .alert("Tên vaccine", isPresented: $editingName) { TextField("Tên", text: $name); Button("Hủy", role: .cancel) {}; Button("Lưu") { if !name.trimmingCharacters(in: .whitespaces).isEmpty { _ = store.commit { s in if let i = s.vaccines.firstIndex(where: { $0.id == id }) { s.vaccines[i].name = name } } } } }
                .sheet(isPresented: $adding) { NavigationStack { VaccinationEditor(vaccineID: id) } }
                .sheet(item: $editingDose) { dose in NavigationStack { VaccinationEditor(vaccineID: id, existing: dose) } }
                .sheet(isPresented: $appointment) { NavigationStack { AppointmentEditor(appointment: { var a = Appointment(title: "Tiêm " + vaccine.name, date: Date().addingTimeInterval(86400)); a.kind = .vaccination; a.vaccineID = id; return a }()) } }
        } else { EmptyNote(title: "Chưa có hồ sơ") }
    }
}
struct VaccinationEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var vaccineID: UUID? = nil
    var appointmentID: UUID? = nil
    var existing: VaccinationDose? = nil
    @State private var name = ""
    @State private var day = Date()
    @State private var number = ""
    @State private var place = ""
    @State private var product = ""
    @State private var lot = ""
    @State private var notes = ""
    @State private var files: [Attachment] = []
    @State private var validation: String?
    var body: some View {
        Form {
            TextField("Tên vaccine", text: $name)
            DatePicker("Ngày đã tiêm", selection: $day, in: ...Date(), displayedComponents: .date)
            TextField("Mũi thứ — bỏ trống nếu chưa rõ", text: $number)
            TextField("Cơ sở tiêm", text: $place)
            TextField("Tên sản phẩm", text: $product)
            TextField("Số lô", text: $lot)
            TextField("Ghi chú", text: $notes, axis: .vertical).lineLimit(2...5)
            Section("Ảnh / PDF phiếu tiêm") { AttachmentPicker(files: $files) }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle(existing == nil ? "Mũi đã tiêm" : "Sửa mũi tiêm")
            .onAppear {
                name = store.snapshot.vaccines.first { $0.id == vaccineID }?.name ?? ""
                if let a = store.snapshot.appointments.first(where: { $0.id == appointmentID }) { place = a.place }
                if let e = existing { day = Day.date(e.day) ?? Date(); number = e.number.map(String.init) ?? ""; place = e.place; product = e.product; lot = e.lot; notes = e.notes; files = store.snapshot.attachments.filter { e.attachmentIDs.contains($0.id) } }
            }
            .editorToolbar(save: save, cancel: { dismiss() })
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { validation = "Hãy nhập tên vaccine."; return }
        guard number.isEmpty || (Int(number).map { $0 > 0 } ?? false) else { validation = "Số mũi cần là số dương hoặc để trống."; return }
        let vaccine = store.snapshot.vaccines.first { $0.id == vaccineID } ?? store.snapshot.vaccines.first { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame } ?? VaccineRecord(name: trimmed)
        var dose = existing ?? VaccinationDose(vaccineID: vaccine.id, day: Day.key(day))
        dose.day = Day.key(day); dose.number = Int(number); dose.product = product; dose.place = place; dose.lot = lot; dose.notes = notes; dose.attachmentIDs = files.map(\.id); dose.appointmentID = appointmentID ?? dose.appointmentID
        if store.commit({ s in
            if !s.vaccines.contains(where: { $0.id == vaccine.id }) { s.vaccines.append(vaccine) }
            s.vaccinations.removeAll { $0.id == dose.id }; s.vaccinations.append(dose)
            for file in files where !s.attachments.contains(where: { $0.id == file.id }) { s.attachments.append(file) }
            if let aid = dose.appointmentID {
                if let i = s.appointments.firstIndex(where: { $0.id == aid }) { s.appointments[i].status = .completed }
                for i in s.tasks.indices where s.tasks[i].appointmentID == aid { s.tasks[i].status = .done }
            }
        }) { dismiss() }
    }
}

struct VaccineImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var files: [Attachment] = []
    @State private var scanning = false
    @State private var processing = false
    @State private var drafts: [VaccineDraft] = []
    @State private var message: String?
    @State private var reminder = false
    @State private var confirmedDates = false
    @State private var mergeDuplicates = true
    @State private var savedCount = 0
    var body: some View {
        Form {
            Section("Phiếu tiêm gốc") {
                #if os(iOS)
                if VNDocumentCameraViewController.isSupported { Button("Chụp phiếu tiêm nhiều trang", systemImage: "doc.viewfinder") { scanning = true }.disabled(processing) }
                #endif
                AttachmentPicker(files: $files).disabled(processing)
                if !files.isEmpty { Button { Task { await recognize() } } label: { Label(processing ? "Đang đọc trên thiết bị…" : "Đọc thông tin từ ảnh", systemImage: "text.viewfinder") }.disabled(processing) }
                Text("Ảnh được xử lý trên thiết bị. Chữ viết tay và bảng nhiều cột có thể cần nhập lại. Luôn đối chiếu với phiếu gốc.").font(.footnote)
            }
            if processing { ProgressView("Đang đọc…") }
            ForEach($drafts) { $draft in
                Section("Mũi tiêm cần kiểm tra") {
                    TextField("Tên vaccine", text: $draft.name)
                    TextField("Ngày đã tiêm · dd/mm/yyyy", text: $draft.injectedDateText)
                    TextField("Mũi thứ · có thể bỏ trống", text: $draft.number)
                    TextField("Tên sản phẩm", text: $draft.product)
                    TextField("Cơ sở tiêm", text: $draft.place)
                    TextField("Số lô", text: $draft.lot)
                    TextField("Ngày hẹn tiếp theo · có thể bỏ trống", text: $draft.nextDateText)
                    DisclosureGroup("Chữ đọc được từ phiếu") { Text(draft.rawText).font(.footnote).textSelection(.enabled) }
                    Toggle("Đã đối chiếu mũi này với ảnh gốc", isOn: $draft.confirmed)
                    Button("Bỏ dòng này", role: .destructive) { drafts.removeAll { $0.id == draft.id } }
                }
            }
            if !drafts.isEmpty {
                Section {
                    Button("Thêm mũi khác trên cùng phiếu") { var draft = VaccineDraft(); draft.rawText = drafts.first?.rawText ?? ""; drafts.append(draft) }
                    Toggle("Gộp ảnh nếu trùng vaccine và ngày tiêm", isOn: $mergeDuplicates)
                    Toggle("Tạo lịch hẹn từ các ngày đã nhập", isOn: $reminder)
                    if reminder { Toggle("Tôi đã xác nhận các ngày hẹn", isOn: $confirmedDates); Text("Giờ nhắc tạm đặt 08:00 ngày hẹn; có thể sửa trong Lịch hẹn. App không suy ra số mũi tiếp theo.").font(.footnote) }
                    PrimaryButton(title: reminder ? "Lưu hồ sơ và lịch hẹn" : "Lưu hồ sơ") { save() }
                }
            }
            if let message { Section { Text(message).foregroundStyle(MomiTheme.rose) } }
        }.momiForm().navigationTitle("Đọc phiếu tiêm")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Đóng") { dismiss() }.disabled(processing) } }
            #if os(iOS)
            .sheet(isPresented: $scanning) {
                DocumentScanner { result in
                    scanning = false
                    do {
                        for data in try result.get() { files.append(try store.importAttachment(data: data, name: "Phiếu tiêm \(files.count + 1).jpg", extension: "jpg")) }
                    } catch { message = error.localizedDescription }
                }.ignoresSafeArea()
            }
            #endif
    }
    private func recognize() async {
        processing = true; message = nil; defer { processing = false }
        do {
            var all: [OCRLine] = []; var offset = 0
            for file in files {
                let data = try Data(contentsOf: store.files.url(file))
                let lines = try await OCRService().recognize(data: data, isPDF: file.filename.hasSuffix(".pdf"))
                all += lines.map { OCRLine(text: $0.text, confidence: $0.confidence, page: $0.page + offset) }
                offset += (lines.map(\.page).max() ?? 0) + 1
            }
            drafts = [VaccineDocumentParser.parse(all)]
            message = "Đã tạo một bản nháp từ chữ đọc được. Nếu phiếu có nhiều mũi, thêm từng mũi và đối chiếu ngày trên ảnh. Các trường chưa rõ được để trống."
        } catch { message = error.localizedDescription; if drafts.isEmpty { drafts = [VaccineDraft()] } }
    }
    private func save() {
        guard !drafts.isEmpty, drafts.allSatisfy({ $0.confirmed && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && Day.parseVietnamese($0.injectedDateText).map { $0 <= store.today } == true }) else { message = "Kiểm tra tên, ngày đã tiêm hợp lệ (không ở tương lai) và xác nhận từng mũi."; return }
        guard drafts.allSatisfy({ $0.number.isEmpty || (Int($0.number).map { $0 > 0 } ?? false) }) else { message = "Số mũi cần là số dương hoặc để trống."; return }
        guard !reminder || (confirmedDates && drafts.allSatisfy { $0.nextDateText.isEmpty || Day.parseVietnamese($0.nextDateText).map { $0 >= store.today } == true }) else { message = "Xác nhận ngày hẹn hợp lệ trước khi tạo lịch."; return }
        Task {
            if reminder { _ = await store.notifications.requestPermission() }
            if store.commit({ s in
                for file in files where !s.attachments.contains(where: { $0.id == file.id }) { s.attachments.append(file) }
                for draft in drafts {
                    let name = draft.name.trimmingCharacters(in: .whitespaces)
                    let vaccine = s.vaccines.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame } ?? VaccineRecord(name: name)
                    if !s.vaccines.contains(where: { $0.id == vaccine.id }) { s.vaccines.append(vaccine) }
                    let day = Day.parseVietnamese(draft.injectedDateText)!
                    if mergeDuplicates, let i = s.vaccinations.firstIndex(where: { $0.vaccineID == vaccine.id && $0.day == day }) {
                        s.vaccinations[i].attachmentIDs = Array(Set(s.vaccinations[i].attachmentIDs + files.map(\.id)))
                    } else {
                        var dose = VaccinationDose(vaccineID: vaccine.id, day: day)
                        dose.number = Int(draft.number); dose.product = draft.product; dose.place = draft.place; dose.lot = draft.lot; dose.attachmentIDs = files.map(\.id)
                        s.vaccinations.append(dose)
                    }
                    if reminder, let next = Day.parseVietnamese(draft.nextDateText), let base = Day.date(next), let date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: base) {
                        if !s.appointments.contains(where: { $0.vaccineID == vaccine.id && Day.key($0.date) == next && $0.status == .scheduled }) {
                            var a = Appointment(title: "Lịch hẹn " + vaccine.name, date: date); a.kind = .vaccination; a.vaccineID = vaccine.id; a.place = draft.place; a.reminderMinutes = [0]; a.notes = "Ngày hẹn từ phiếu tiêm đã kiểm tra. Chưa xác định số mũi tiếp theo."; s.appointments.append(a)
                        }
                    }
                }
            }) { dismiss() }
        }
    }
}

struct AttachmentLinks: View {
    @Environment(AppStore.self) private var store
    var ids: [UUID]
    @State private var preview: URL?
    var body: some View {
        ForEach(store.snapshot.attachments.filter { ids.contains($0.id) }) { file in Button(file.displayName, systemImage: "paperclip") { preview = store.files.url(file) }.font(.subheadline) }
            .quickLookPreview($preview)
    }
}
struct AttachmentPicker: View {
    @Environment(AppStore.self) private var store
    @Binding var files: [Attachment]
    @State private var photos: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var busy = false
    @State private var message: String?
    @State private var preview: URL?
    var body: some View {
        ForEach(files) { file in
            HStack { Button(file.displayName, systemImage: "doc") { preview = store.files.url(file) }; Spacer(); Button { files.removeAll { $0.id == file.id } } label: { Image(systemName: "xmark.circle").accessibilityLabel("Bỏ file " + file.displayName) }.buttonStyle(.plain) }
        }
        PhotosPicker(selection: $photos, maxSelectionCount: 10, matching: .images) { Label("Chọn ảnh", systemImage: "photo") }.disabled(busy)
        Button("Chọn PDF hoặc ảnh từ Files", systemImage: "folder") { importing = true }.disabled(busy)
        if busy { ProgressView("Đang lưu ảnh…") }
        if let message { Text(message).font(.footnote).foregroundStyle(.red) }
        Color.clear.frame(height: 0)
            .onChange(of: photos) { _, items in
                Task {
                    busy = true; defer { busy = false; photos = [] }
                    do {
                        for item in items {
                            guard let data = try await item.loadTransferable(type: Data.self) else { throw ValidationError.message("Không đọc được ảnh.") }
                            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                            files.append(try store.importAttachment(data: data, name: "Ảnh \(files.count + 1).\(ext)", extension: ext))
                        }
                    } catch { message = error.localizedDescription }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                do {
                    for url in try result.get() {
                        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                        files.append(try store.importAttachment(data: Data(contentsOf: url), name: url.lastPathComponent, extension: url.pathExtension))
                    }
                } catch { message = error.localizedDescription }
            }
            .quickLookPreview($preview)
    }
}
