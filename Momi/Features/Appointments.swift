import SwiftUI
import MomiCore

struct AppointmentsView: View {
    @Environment(AppStore.self) private var store
    @State private var adding = false
    @State private var showPast = false
    var body: some View {
        List {
            Toggle("Xem cả lịch cũ và đã hủy", isOn: $showPast)
            ForEach(store.snapshot.appointments.filter { showPast || ($0.status == .scheduled && $0.date >= Calendar.current.startOfDay(for: Date())) }.sorted { $0.date < $1.date }) { a in
                NavigationLink { AppointmentDetail(id: a.id) } label: {
                    VStack(alignment: .leading, spacing: 6) { Text(a.title).font(.headline); Text(a.date.momiDate + " · " + a.date.momiTime).font(.subheadline); Text(a.kind.title + " · " + a.status.title).font(.caption).foregroundStyle(MomiTheme.muted) }
                }
            }
            if store.snapshot.appointments.isEmpty { EmptyNote(title: "Chưa có lịch hẹn", symbol: "calendar") }
        }.momiForm().navigationTitle("Lịch hẹn")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { adding = true } label: { Image(systemName: "plus").accessibilityLabel("Thêm lịch hẹn") } } }
            .sheet(isPresented: $adding) { NavigationStack { AppointmentEditor(appointment: Appointment(title: "", date: Date().addingTimeInterval(86400))) } }
    }
}
struct AppointmentDetail: View {
    @Environment(AppStore.self) private var store
    var id: UUID
    @State private var editing = false
    @State private var cancelling = false
    @State private var record = false
    @State private var dose = false
    var appointment: Appointment? { store.snapshot.appointments.first { $0.id == id } }
    var body: some View {
        if let a = appointment {
            MomiPage {
                MomiCard {
                    Text(a.title).font(.title2.bold())
                    Label(a.date.momiDate + " · " + a.date.momiTime, systemImage: "calendar")
                    if !a.place.isEmpty { Label(a.place, systemImage: "mappin.and.ellipse") }
                    Text(a.status.title).foregroundStyle(MomiTheme.green)
                    if let old = a.previousDate { Text("Đã đổi từ " + old.momiDate + " · " + old.momiTime).font(.caption) }
                    if !a.notes.isEmpty { Text(a.notes) }
                    if !a.questions.isEmpty { Divider(); Text("Câu hỏi muốn trao đổi").font(.headline); Text(a.questions) }
                }
                if a.status == .scheduled {
                    PrimaryButton(title: a.kind == .vaccination ? "Ghi nhận đã tiêm" : "Đánh dấu hoàn thành") {
                        if a.kind == .vaccination { dose = true }
                        else { _ = store.commit { s in if let i = s.appointments.firstIndex(where: { $0.id == id }) { s.appointments[i].status = .completed } } }
                    }
                    Button("Hủy lịch hẹn", role: .destructive) { cancelling = true }
                }
                if a.kind == .examination { Button("Lưu hồ sơ cho lần khám này") { record = true }.buttonStyle(.bordered) }
            }.navigationTitle("Lịch hẹn").toolbar { Button("Sửa") { editing = true } }
                .sheet(isPresented: $editing) { NavigationStack { AppointmentEditor(appointment: a) } }
                .sheet(isPresented: $record) { NavigationStack { RecordEditor(record: { var r = HealthRecord(title: a.title, day: Day.key(a.date)); r.place = a.place; r.appointmentID = a.id; return r }()) } }
                .sheet(isPresented: $dose) { NavigationStack { VaccinationEditor(vaccineID: a.vaccineID, appointmentID: a.id) } }
                .confirmationDialog("Hủy lịch và các lời nhắc liên quan?", isPresented: $cancelling, titleVisibility: .visible) { Button("Hủy lịch hẹn", role: .destructive) { _ = store.commit { s in if let i = s.appointments.firstIndex(where: { $0.id == id }) { s.appointments[i].status = .cancelled } } } }
        } else { EmptyNote(title: "Không tìm thấy lịch hẹn") }
    }
}
struct AppointmentEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var appointment: Appointment
    @State private var dayBefore = false
    @State private var hourBefore = false
    @State private var atTime = false
    @State private var validation: String?
    var body: some View {
        Form {
            Section("Lịch của bạn") {
                TextField("Tên lịch hẹn", text: $appointment.title)
                Picker("Loại", selection: $appointment.kind) { ForEach(AppointmentKind.allCases, id: \.self) { Text($0.title).tag($0) } }
                DatePicker("Ngày và giờ", selection: $appointment.date)
                TextField("Địa điểm", text: $appointment.place)
                TextField("Ghi chú", text: $appointment.notes, axis: .vertical).lineLimit(2...6)
                if appointment.kind == .vaccination {
                    Picker("Hồ sơ vaccine", selection: $appointment.vaccineID) { Text("Chưa liên kết").tag(nil as UUID?); ForEach(store.snapshot.vaccines) { Text($0.name).tag(Optional($0.id)) } }
                }
            }
            Section("Câu hỏi muốn hỏi") { TextEditor(text: $appointment.questions).frame(minHeight: 100) }
            Section("Nhắc nhở") { Toggle("Trước 1 ngày", isOn: $dayBefore); Toggle("Trước 1 giờ", isOn: $hourBefore); Toggle("Đúng giờ hẹn", isOn: $atTime) }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle("Lịch hẹn")
            .onAppear { dayBefore = appointment.reminderMinutes.contains(1440); hourBefore = appointment.reminderMinutes.contains(60); atTime = appointment.reminderMinutes.contains(0) }
            .editorToolbar(save: {
                guard !appointment.title.trimmingCharacters(in: .whitespaces).isEmpty else { validation = "Hãy nhập tên lịch hẹn."; return }
                appointment.reminderMinutes = (dayBefore ? [1440] : []) + (hourBefore ? [60] : []) + (atTime ? [0] : [])
                if let old = store.snapshot.appointments.first(where: { $0.id == appointment.id }), old.date != appointment.date { appointment.previousDate = old.date }
                Task {
                    if !appointment.reminderMinutes.isEmpty { _ = await store.notifications.requestPermission() }
                    if store.commit({ s in s.appointments.removeAll { $0.id == appointment.id }; s.appointments.append(appointment) }) { dismiss() }
                }
            }, cancel: { dismiss() })
    }
}
