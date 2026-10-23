import SwiftUI
import MomiCore

struct PregnancyJourneyView: View {
    @Environment(AppStore.self) private var store
    @Binding var changeStage: Bool
    @State private var selectedWeek = 4
    @State private var initialized = false
    private var age: GestationalAge? { PregnancyTimeline.age(dueDate: store.snapshot.profile.dueDate, on: store.today) }
    private var nextAppointment: Appointment? {
        store.snapshot.appointments.filter { $0.status == .scheduled && $0.kind == .examination && $0.date >= Date() }.sorted { $0.date < $1.date }.first
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            pregnancyHeader
            weekSelector
            motherAndBaby
            UltrasoundWeekSection(week: selectedWeek)
            appointmentCard
            checklistCard
            quickLinks
        }
        .onAppear { if !initialized { selectedWeek = age?.week ?? 4; initialized = true } }
        .onChange(of: store.snapshot.profile.dueDate) { _, _ in selectedWeek = age?.week ?? selectedWeek }
        .onChange(of: store.today) { previous, _ in
            if selectedWeek == PregnancyTimeline.age(dueDate: store.snapshot.profile.dueDate, on: previous)?.week,
               let current = age?.week { selectedWeek = current }
        }
    }
    private var pregnancyHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Đang mang thai").font(.subheadline.bold()).foregroundStyle(MomiTheme.rose)
            if let age {
                Text("Tuần \(age.week)").font(.system(.largeTitle, design: .rounded).bold()).foregroundStyle(MomiTheme.ink)
                if age.remainder > 0 { Text("+ \(age.remainder) ngày").font(.subheadline).foregroundStyle(MomiTheme.muted) }
            } else { Text("Chưa rõ tuần thai").font(.title.bold()).foregroundStyle(MomiTheme.ink) }
            if let due = store.snapshot.profile.dueDate {
                Text("Dự sinh \(Day.display(due)) · theo thông tin bạn đã nhập").font(.subheadline).foregroundStyle(MomiTheme.muted)
                if age == nil { Text("Cập nhật ngày dự sinh để xác định tuần thai hiện tại.").font(.footnote).foregroundStyle(MomiTheme.rose) }
            } else { Text("Bạn có thể thêm ngày dự sinh để theo dõi tuần hiện tại.").font(.subheadline).foregroundStyle(MomiTheme.muted) }
            Button { changeStage = true } label: {
                Text("Cập nhật giai đoạn").font(.headline).padding(.horizontal, 16).padding(.vertical, 12)
                    .foregroundStyle(MomiTheme.muted).background(MomiTheme.card, in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).padding(.top, 5)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(alignment: .bottomTrailing) { Circle().fill(MomiTheme.rose.opacity(0.09)).frame(width: 155, height: 155).offset(x: 35, y: 40) }
            .background(MomiTheme.pregnancyPink, in: RoundedRectangle(cornerRadius: 24))
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    private var weekSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(age?.week == selectedWeek ? "Tuần hiện tại" : "Đang xem tuần \(selectedWeek)").font(.caption).foregroundStyle(MomiTheme.muted)
                Spacer()
                if let age, selectedWeek != age.week { Button("Về tuần hiện tại") { selectedWeek = age.week }.font(.caption) }
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(PregnancyTimeline.weeks, id: \.self) { week in
                            Button { selectedWeek = week } label: {
                                VStack(spacing: 3) {
                                    Text("Tuần").font(.caption)
                                    Text("\(week)").font(.title3.bold())
                                }.frame(minWidth: 51, minHeight: 58).padding(.horizontal, 3)
                                    .foregroundStyle(selectedWeek == week ? .white : MomiTheme.ink)
                                    .background(selectedWeek == week ? MomiTheme.rose : MomiTheme.card, in: RoundedRectangle(cornerRadius: 15))
                                    .overlay { RoundedRectangle(cornerRadius: 15).stroke(selectedWeek == week ? MomiTheme.rose : MomiTheme.border, lineWidth: 1) }
                            }.buttonStyle(.plain).id(week)
                                .accessibilityLabel("Tuần \(week)" + (age?.week == week ? ", tuần hiện tại" : ""))
                                .accessibilityAddTraits(selectedWeek == week ? .isSelected : [])
                        }
                    }.padding(.vertical, 2)
                }.onAppear { proxy.scrollTo(selectedWeek, anchor: .center) }
                    .onChange(of: selectedWeek) { _, week in withAnimation { proxy.scrollTo(week, anchor: .center) } }
            }
        }
    }
    private var motherAndBaby: some View {
        let guide = PregnancyGuide.forWeek(selectedWeek)
        return JourneyCard {
            HStack(alignment: .firstTextBaseline) {
                Text("Tuần \(selectedWeek)").font(.title3.bold())
                Spacer()
                Text("Tham khảo").font(.caption).foregroundStyle(MomiTheme.muted)
            }
            guideRow("Mẹ", text: guide.mother, icon: "figure.stand.dress", color: MomiTheme.rose)
            guideRow("Bé", text: guide.baby, icon: "face.smiling", color: MomiTheme.green)
            Text(guide.heading).font(.caption).foregroundStyle(MomiTheme.muted)
            Link("Đọc thêm tại NHS", destination: guide.source).font(.caption).foregroundStyle(MomiTheme.green)
        }
    }
    private func guideRow(_ title: String, text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.subheadline.bold()).foregroundStyle(color); Text(text).font(.subheadline).foregroundStyle(MomiTheme.ink) }
        }
    }
    private var appointmentCard: some View {
        JourneyCard {
            if let appointment = nextAppointment {
                NavigationLink { AppointmentDetail(id: appointment.id) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "stethoscope").font(.title2).foregroundStyle(MomiTheme.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lịch khám sắp tới").font(.subheadline).foregroundStyle(MomiTheme.muted)
                            Text(appointment.title).font(.headline).foregroundStyle(MomiTheme.ink)
                            Text(appointment.date.momiDate + " · " + appointment.date.momiTime).font(.subheadline).foregroundStyle(MomiTheme.muted)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            } else {
                Label("Lịch khám sắp tới", systemImage: "stethoscope").font(.headline).foregroundStyle(MomiTheme.green)
                Text("Chưa có lịch khám đã xác nhận.").font(.subheadline).foregroundStyle(MomiTheme.muted)
                NavigationLink("Thêm lịch khám") { AppointmentsView() }
            }
        }
    }
    private var checklistCard: some View {
        let tasks = PregnancyTimeline.checklist(store.snapshot)
        return JourneyCard {
            HStack {
                Text("Checklist theo giai đoạn").font(.headline)
                Spacer()
                NavigationLink("Xem hết") { ChecklistView() }.font(.caption)
            }
            if tasks.isEmpty { Text("Thêm những việc bạn muốn chuẩn bị trong thai kỳ.").font(.subheadline).foregroundStyle(MomiTheme.muted); NavigationLink("Thêm việc cần làm") { ChecklistView() } }
            ForEach(Array(tasks.prefix(3))) { TaskCheckRow(item: $0) }
        }
    }
    private var quickLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) { tiles }
            VStack(spacing: 8) { tiles }
        }
    }
    @ViewBuilder private var tiles: some View {
        NavigationLink { NutritionView() } label: { JourneyTile(title: "Dinh dưỡng", icon: "fork.knife", color: MomiTheme.rose) }
        NavigationLink { JournalView() } label: { JourneyTile(title: "Nhật ký", icon: "square.and.pencil", color: MomiTheme.green) }
        NavigationLink { UltrasoundsView(initialWeek: selectedWeek) } label: { JourneyTile(title: "Ảnh siêu âm", icon: "photo.on.rectangle", color: MomiTheme.muted) }
    }
}

struct JourneyCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14, content: content).frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(MomiTheme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(MomiTheme.border, lineWidth: 1) }
    }
}
private struct JourneyTile: View {
    var title: String
    var icon: String
    var color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(title).font(.subheadline.bold()).foregroundStyle(MomiTheme.ink).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).padding(13)
            .background(MomiTheme.card, in: RoundedRectangle(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).stroke(MomiTheme.border, lineWidth: 1) }
            .contentShape(RoundedRectangle(cornerRadius: 17))
    }
}
