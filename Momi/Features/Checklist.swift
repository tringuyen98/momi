import SwiftUI
import MomiCore

struct ChecklistView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: TaskStatus = .todo
    @State private var editing: ChecklistItem?
    @State private var showNew = false
    var items: [ChecklistItem] { store.snapshot.tasks.filter { $0.status == filter }.sorted { ($0.dueDay ?? "9999") < ($1.dueDay ?? "9999") } }
    var body: some View {
        List {
            Picker("Trạng thái", selection: $filter) { ForEach(TaskStatus.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            if items.isEmpty { EmptyNote(title: "Chưa có việc trong mục này", symbol: "checklist") }
            ForEach(items) { item in
                TaskCheckRow(item: item)
                    .swipeActions { Button("Sửa") { editing = item }.tint(MomiTheme.green); Button("Lưu trữ") { _ = store.commit { s in if let i = s.tasks.firstIndex(where: { $0.id == item.id }) { s.tasks[i].status = .archived } } }.tint(.gray) }
                    .contextMenu { Button("Sửa việc") { editing = item } }
            }
        }.momiForm().navigationTitle("Checklist của mẹ")
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { showNew = true } label: { Image(systemName: "plus").accessibilityLabel("Thêm việc") } } }
            .sheet(isPresented: $showNew) { NavigationStack { TaskEditor(item: ChecklistItem(title: "")) } }
            .sheet(item: $editing) { item in NavigationStack { TaskEditor(item: item) } }
    }
}
struct TaskCheckRow: View {
    @Environment(AppStore.self) private var store
    var item: ChecklistItem
    @State private var editing = false
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                _ = store.commit { s in if let i = s.tasks.firstIndex(where: { $0.id == item.id }) { s.tasks[i].status = item.status == .done ? .todo : .done } }
            } label: { Image(systemName: item.status == .done ? "checkmark.circle.fill" : "circle").font(.title2).foregroundStyle(MomiTheme.green).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel(item.status == .done ? "Hoàn tác hoàn thành" : "Đánh dấu đã xong")
            Button { editing = true } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).foregroundStyle(MomiTheme.ink).strikethrough(item.status == .done)
                    Text(item.group + (item.dueDay.map { " · " + Day.display($0) } ?? "")).font(.caption).foregroundStyle(MomiTheme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
        }.sheet(isPresented: $editing) { NavigationStack { TaskEditor(item: item) } }
    }
}
struct TaskEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var item: ChecklistItem
    @State private var hasDate = false
    @State private var date = Date()
    @State private var hasReminder = false
    @State private var reminder = Date().addingTimeInterval(3600)
    @State private var validation: String?
    var body: some View {
        Form {
            Section("Việc của bạn") { TextField("Tên việc", text: $item.title); TextField("Nhóm", text: $item.group); TextField("Ghi chú", text: $item.notes, axis: .vertical).lineLimit(3...7) }
            Section("Thời gian") { Toggle("Đặt ngày thực hiện", isOn: $hasDate); if hasDate { DatePicker("Ngày", selection: $date, displayedComponents: .date) }; Toggle("Nhắc tôi", isOn: $hasReminder); if hasReminder { DatePicker("Nhắc lúc", selection: $reminder) } }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle("Việc cần chuẩn bị")
            .onAppear { hasDate = item.dueDay != nil; date = item.dueDay.flatMap { Day.date($0) } ?? Date(); hasReminder = item.reminder != nil; reminder = item.reminder ?? Date().addingTimeInterval(3600) }
            .editorToolbar(save: {
                guard !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { validation = "Hãy đặt tên cho việc này."; return }
                guard !hasReminder || reminder > Date() else { validation = "Giờ nhắc cần nằm trong tương lai."; return }
                item.dueDay = hasDate ? Day.key(date) : nil; item.reminder = hasReminder ? reminder : nil
                Task { if hasReminder { _ = await store.notifications.requestPermission() }; if store.commit({ s in s.tasks.removeAll { $0.id == item.id }; s.tasks.append(item) }) { dismiss() } }
            }, cancel: { dismiss() })
    }
}
