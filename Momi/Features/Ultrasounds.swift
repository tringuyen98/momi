import SwiftUI
import QuickLook
import MomiCore
#if os(iOS)
import UIKit
import ImageIO
import UniformTypeIdentifiers
import VisionKit
#endif

struct UltrasoundWeekSection: View {
    @Environment(AppStore.self) private var store
    var week: Int
    @State private var adding: UltrasoundEntry?
    @State private var preview: URL?
    private var entries: [UltrasoundEntry] { PregnancyTimeline.entries(store.snapshot, week: week) }
    private var files: [Attachment] {
        let ids = entries.flatMap(\.attachmentIDs)
        return ids.compactMap { id in store.snapshot.attachments.first { $0.id == id } }
    }
    var body: some View {
        JourneyCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Ảnh siêu âm · tuần \(week)").font(.headline)
                Spacer()
                if !entries.isEmpty { NavigationLink("Xem hết") { UltrasoundsView(initialWeek: week) }.font(.caption) }
            }
            if files.isEmpty {
                Image(systemName: "photo.badge.plus").font(.largeTitle).foregroundStyle(MomiTheme.rose.opacity(0.65)).frame(maxWidth: .infinity).padding(.vertical, 14).accessibilityHidden(true)
                Text("Chưa có ảnh siêu âm ở tuần này. Thêm ảnh để lưu lại một mốc của hai mẹ con.").font(.subheadline).foregroundStyle(MomiTheme.muted)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(files.prefix(4))) { file in
                        Button { preview = store.files.url(file) } label: { UltrasoundThumbnail(file: file).frame(height: 125).clipped() }.buttonStyle(.plain).accessibilityLabel("Xem " + file.displayName)
                    }
                }
                Text("\(entries.count) lần ghi · \(files.count) ảnh / PDF").font(.caption).foregroundStyle(MomiTheme.muted)
            }
            Button { adding = UltrasoundEntry(week: week, day: store.today) } label: {
                Label("Thêm ảnh cho tuần \(week)", systemImage: "plus").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 7)
            }.buttonStyle(.bordered).tint(MomiTheme.rose)
        }
        .sheet(item: $adding) { entry in NavigationStack { UltrasoundEditor(entry: entry) } }
        .quickLookPreview($preview)
    }
}

struct UltrasoundsView: View {
    @Environment(AppStore.self) private var store
    @State private var week: Int?
    @State private var editing: UltrasoundEntry?
    @State private var deleting: UltrasoundEntry?
    @State private var preview: URL?
    init(initialWeek: Int? = nil) { _week = State(initialValue: initialWeek) }
    private var entries: [UltrasoundEntry] {
        store.snapshot.ultrasounds.filter { week == nil || $0.week == week }.sorted { ($0.week, $0.day) > ($1.week, $1.day) }
    }
    var body: some View {
        MomiPage {
            Picker("Tuần thai", selection: $week) {
                Text("Tất cả tuần").tag(Optional<Int>.none)
                ForEach(PregnancyTimeline.weeks, id: \.self) { Text("Tuần \($0)").tag(Optional($0)) }
            }.pickerStyle(.menu)
            if entries.isEmpty {
                JourneyCard {
                    Label(week.map { "Chưa có ảnh ở tuần \($0)" } ?? "Lưu những lần đầu nhìn thấy bé", systemImage: "photo.on.rectangle").font(.headline)
                    Text("Chọn ảnh từ thư viện, chụp phiếu hoặc tải ảnh/PDF. Mỗi lần ghi gắn với một tuần thai.").font(.subheadline).foregroundStyle(MomiTheme.muted)
                    Button("Thêm ảnh siêu âm") { newEntry() }
                }
            }
            ForEach(entries) { entry in
                JourneyCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) { Text("Tuần \(entry.week)").font(.headline); Text(Day.display(entry.day)).font(.caption).foregroundStyle(MomiTheme.muted) }
                        Spacer()
                        Button("Sửa") { editing = entry }
                    }
                    if !entry.notes.isEmpty { Text(entry.notes).font(.subheadline) }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(store.snapshot.attachments.filter { entry.attachmentIDs.contains($0.id) }) { file in
                            Button { preview = store.files.url(file) } label: {
                                VStack(alignment: .leading, spacing: 5) { UltrasoundThumbnail(file: file).frame(height: 135).clipped(); Text(file.displayName).font(.caption).lineLimit(2).foregroundStyle(MomiTheme.muted) }
                            }.buttonStyle(.plain).accessibilityLabel("Xem " + file.displayName)
                        }
                    }
                    Button("Xóa lần ghi này", role: .destructive) { deleting = entry }.font(.subheadline)
                }
            }
            Text("Ảnh giữ nguyên tuần đã lưu khi bạn đổi ngày dự sinh. Có thể sửa tuần trong từng lần ghi.").font(.footnote).foregroundStyle(MomiTheme.muted)
        }.navigationTitle("Ảnh siêu âm")
            .toolbar { Button { newEntry() } label: { Image(systemName: "plus").accessibilityLabel("Thêm ảnh siêu âm") } }
            .sheet(item: $editing) { entry in NavigationStack { UltrasoundEditor(entry: entry) } }
            .alert("Xóa lần ghi siêu âm?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { entry in
                Button("Hủy", role: .cancel) { deleting = nil }
                Button("Xóa", role: .destructive) {
                    if store.commit({ PregnancyTimeline.remove(entry.id, from: &$0) }) { store.files.cleanup(keeping: store.snapshot); deleting = nil }
                }
            } message: { entry in Text("Xóa ghi chú và ảnh của lần ghi tuần \(entry.week). Ảnh đang dùng ở hồ sơ khác vẫn được giữ lại.") }
            .quickLookPreview($preview)
    }
    private func newEntry() {
        let current = PregnancyTimeline.age(dueDate: store.snapshot.profile.dueDate, on: store.today)?.week
        editing = UltrasoundEntry(week: week ?? current ?? 4, day: store.today)
    }
}

struct UltrasoundEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var entry: UltrasoundEntry
    @State private var date = Date()
    @State private var files: [Attachment] = []
    @State private var busy = false
    @State private var scanning = false
    @State private var validation: String?
    var body: some View {
        Form {
            Section("Lưu theo tuần thai") {
                Picker("Tuần của ảnh", selection: $entry.week) { ForEach(PregnancyTimeline.weeks, id: \.self) { Text("Tuần \($0)").tag($0) } }
                DatePicker("Ngày siêu âm", selection: $date, in: ...Date(), displayedComponents: .date)
                Text("Đang lưu cho tuần \(entry.week). Bạn có thể chỉnh theo tuổi thai ghi trên phiếu; app không tự suy ra từ ảnh.").font(.footnote)
            }
            Section("Ảnh / PDF siêu âm") {
                #if os(iOS)
                if VNDocumentCameraViewController.isSupported { Button("Chụp phiếu siêu âm", systemImage: "doc.viewfinder") { scanning = true }.disabled(busy) }
                #endif
                AttachmentPicker(files: $files, isBusy: $busy)
            }
            Section("Ghi chú của mẹ") { TextField("Một vài điều muốn lưu lại…", text: $entry.notes, axis: .vertical).lineLimit(3...8) }
            if let validation { Text(validation).foregroundStyle(.red) }
        }.momiForm().navigationTitle("Ảnh siêu âm · tuần \(entry.week)")
            .onAppear { date = min(Day.date(entry.day) ?? Date(), Date()); files = entry.attachmentIDs.compactMap { id in store.snapshot.attachments.first { $0.id == id } } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button("Lưu", action: save).fontWeight(.semibold).disabled(busy) }
            }
            .interactiveDismissDisabled(busy)
            #if os(iOS)
            .sheet(isPresented: $scanning) {
                DocumentScanner { result in
                    scanning = false
                    do { for data in try result.get() { files.append(try store.importAttachment(data: data, name: "Siêu âm tuần \(entry.week) · \(files.count + 1).jpg", extension: "jpg")) } }
                    catch { validation = error.localizedDescription }
                }.ignoresSafeArea()
            }
            #endif
    }
    private func save() {
        guard !busy else { return }
        guard !files.isEmpty else { validation = "Hãy chọn ít nhất một ảnh hoặc PDF siêu âm."; return }
        entry.day = Day.key(date); entry.attachmentIDs = files.map(\.id)
        if store.commit({ try PregnancyTimeline.save(entry, files: files, in: &$0) }) { dismiss() }
    }
}

private struct UltrasoundThumbnail: View {
    @Environment(AppStore.self) private var store
    var file: Attachment
    @State private var data: Data?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(MomiTheme.pregnancyPink.opacity(0.6))
            #if os(iOS)
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
            else { placeholder }
            #else
            placeholder
            #endif
        }.clipShape(RoundedRectangle(cornerRadius: 12))
            .task(id: file.filename) {
                #if os(iOS)
                let url = store.files.url(file)
                guard url.pathExtension.lowercased() != "pdf" else { return }
                data = await Task.detached(priority: .utility) {
                    guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 640] as CFDictionary) else { return nil as Data? }
                    let buffer = NSMutableData()
                    guard let destination = CGImageDestinationCreateWithData(buffer, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
                    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
                    guard CGImageDestinationFinalize(destination) else { return nil }
                    return buffer as Data
                }.value
                #endif
            }
    }
    private var placeholder: some View {
        VStack(spacing: 8) { Image(systemName: file.filename.hasSuffix(".pdf") ? "doc.richtext" : "photo").font(.largeTitle); Text(file.filename.hasSuffix(".pdf") ? "Mở PDF" : "Mở ảnh").font(.caption) }.foregroundStyle(MomiTheme.muted)
    }
}
