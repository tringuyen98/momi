import SwiftUI
import MomiCore

enum MomiTheme {
    static let background = Color(red: 0.965, green: 0.945, blue: 0.914)
    static let card = Color(red: 0.999, green: 0.989, blue: 0.971)
    static let green = Color(red: 0.30, green: 0.43, blue: 0.34)
    static let ink = Color(red: 0.165, green: 0.141, blue: 0.125)
    static let muted = Color(red: 0.39, green: 0.34, blue: 0.30)
    static let pregnancyPink = Color(red: 0.957, green: 0.890, blue: 0.867)
    static let border = Color(red: 0.918, green: 0.882, blue: 0.827)
    static let rose = Color(red: 0.55, green: 0.29, blue: 0.25)
}
struct MomiCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View { VStack(alignment: .leading, spacing: 12, content: content).frame(maxWidth: .infinity, alignment: .leading).padding(18).background(MomiTheme.card, in: RoundedRectangle(cornerRadius: 20)) }
}
struct MomiPage<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 20, content: content).padding(20) }.background(MomiTheme.background) }
}
struct SectionHeading: View {
    var title: String
    var body: some View { Text(title).font(.title3.bold()).foregroundStyle(MomiTheme.ink) }
}
struct EmptyNote: View {
    var title: String
    var message: String = "Bạn có thể thêm khi cần."
    var symbol: String = "leaf"
    var body: some View { ContentUnavailableView(title, systemImage: symbol, description: Text(message)).foregroundStyle(MomiTheme.muted) }
}
struct PrimaryButton: View {
    var title: String
    var action: () -> Void
    var body: some View { Button(action: action) { Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 7) }.buttonStyle(.borderedProminent).tint(MomiTheme.green).controlSize(.large) }
}
struct RouteRow: View {
    var title: String
    var subtitle: String
    var icon: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(MomiTheme.green).frame(width: 42, height: 42).background(MomiTheme.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(subtitle).font(.subheadline).foregroundStyle(MomiTheme.muted) }
            Spacer(minLength: 4); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 5).contentShape(Rectangle())
    }
}
extension View {
    func momiForm() -> some View { self.scrollContentBackground(.hidden).background(MomiTheme.background) }
    func editorToolbar(save: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Hủy", action: cancel) }
            ToolbarItem(placement: .confirmationAction) { Button("Lưu", action: save).fontWeight(.semibold) }
        }
    }
}
extension Date {
    var momiDate: String { formatted(.dateTime.day().month().year().locale(Locale(identifier: "vi_VN"))) }
    var momiTime: String { formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute()) }
}
