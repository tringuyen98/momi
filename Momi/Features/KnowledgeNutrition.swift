import SwiftUI
import MomiCore

struct KnowledgeView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var savedOnly = false
    var articles: [Article] { ContentLibrary.articles.filter { (!savedOnly || store.snapshot.bookmarks.contains($0.id)) && (query.isEmpty || ($0.title + $0.topic + $0.summary).localizedStandardContains(query)) } }
    var body: some View {
        MomiPage {
            Toggle("Chỉ xem bài đã lưu", isOn: $savedOnly)
            ForEach(articles) { a in
                NavigationLink { ArticleDetail(article: a) } label: {
                    MomiCard { Text(a.topic).font(.caption).foregroundStyle(MomiTheme.green); Text(a.title).font(.headline); Text(a.summary).font(.subheadline).foregroundStyle(MomiTheme.muted) }
                }.buttonStyle(.plain)
            }
            if articles.isEmpty { EmptyNote(title: "Chưa có bài phù hợp", symbol: "book") }
            Text("Nội dung khởi đầu có liên kết nguồn để đọc thêm, chưa được bác sĩ Việt Nam duyệt riêng cho ứng dụng.").font(.footnote).foregroundStyle(MomiTheme.muted)
        }.navigationTitle("Kiến thức").searchable(text: $query, prompt: "Tìm theo chủ đề hoặc câu hỏi")
    }
}
struct ArticleDetail: View {
    @Environment(AppStore.self) private var store
    var article: Article
    @State private var task = false
    @State private var question = false
    @State private var text = ""
    @State private var appointmentID: UUID?
    @State private var questionMessage: String?
    var body: some View {
        MomiPage {
            Text(article.topic).font(.subheadline).foregroundStyle(MomiTheme.green)
            Text(article.title).font(.largeTitle.bold())
            Text(article.summary).font(.title3).foregroundStyle(MomiTheme.muted)
            Text(article.body).font(.body).lineSpacing(6).textSelection(.enabled)
            MomiCard { Text("Nguồn đọc thêm").font(.headline); if let url = URL(string: article.sourceURL) { Link(article.sourceTitle, destination: url) }; Text("Nội dung biên soạn: 23/10/2026. Hãy xem bản cập nhật ở nguồn và trao đổi với cơ sở y tế khi áp dụng.").font(.footnote).foregroundStyle(MomiTheme.muted) }
            Button(store.snapshot.bookmarks.contains(article.id) ? "Bỏ lưu bài" : "Lưu bài", systemImage: "bookmark") { _ = store.commit { if $0.bookmarks.contains(article.id) { $0.bookmarks.removeAll { $0 == article.id } } else { $0.bookmarks.append(article.id) } } }.buttonStyle(.bordered)
            Button("Thêm việc vào checklist") { task = true }
            Button("Lưu câu hỏi vào lịch khám") { question = true }
        }.navigationTitle("Bài đọc")
            .sheet(isPresented: $task) { NavigationStack { TaskEditor(item: { var t = ChecklistItem(title: "Tìm hiểu: " + article.title); t.notes = article.sourceURL; return t }()) } }
            .sheet(isPresented: $question) {
                NavigationStack {
                    Form {
                        TextField("Điều bạn muốn hỏi", text: $text, axis: .vertical).lineLimit(3...8)
                        Picker("Lịch khám", selection: $appointmentID) { Text("Chọn lịch khám").tag(nil as UUID?); ForEach(store.snapshot.appointments.filter { $0.kind == .examination && $0.status == .scheduled }) { Text($0.title).tag(Optional($0.id)) } }
                        Text("Nếu chưa có lịch khám, bạn có thể lưu câu hỏi thành việc trong checklist.").font(.footnote)
                        if let questionMessage { Text(questionMessage).foregroundStyle(.red) }
                    }.navigationTitle("Câu hỏi của bạn").editorToolbar(save: {
                        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { questionMessage = "Hãy nhập câu hỏi."; return }
                        if store.commit({ s in
                            if let id = appointmentID, let i = s.appointments.firstIndex(where: { $0.id == id }) { s.appointments[i].questions += (s.appointments[i].questions.isEmpty ? "" : "\n") + text }
                            else { var t = ChecklistItem(title: "Hỏi bác sĩ: " + text); t.group = "Chuẩn bị đi khám"; t.notes = article.sourceURL; s.tasks.append(t) }
                        }) { question = false }
                    }, cancel: { question = false })
                }
            }
    }
}
struct NutritionView: View {
    @Environment(AppStore.self) private var store
    @State private var preferences = false
    @State private var selectedDay = Date()
    @State private var savedOnly = false
    var foods: [Food] {
        ContentLibrary.foods.filter { food in
            (!store.snapshot.profile.vegetarian || food.vegetarian) && Set(food.allergens).isDisjoint(with: store.snapshot.profile.allergies) && (!savedOnly || store.snapshot.savedFoods.contains(food.id))
        }
    }
    var body: some View {
        MomiPage {
            NavigationLink { SupplementsView() } label: { MomiCard { RouteRow(title: "Vitamin & bổ sung", subtitle: "Sản phẩm đang dùng và lịch uống", icon: "pills") } }.buttonStyle(.plain)
            MomiCard { Text("Ăn uống theo cách phù hợp với mình").font(.headline); Text("Gợi ý món để bạn lựa chọn. Momi không đánh giá thiếu chất hoặc kê thực đơn điều trị.").font(.subheadline).foregroundStyle(MomiTheme.muted); Button("Sở thích & dị ứng") { preferences = true } }
            SectionHeading(title: "Tìm hiểu dưỡng chất")
            NavigationLink { ArticleDetail(article: ContentLibrary.articles.first { $0.id == "folate" }!) } label: { RouteRow(title: "Folate và axit folic", subtitle: "Thực phẩm và sản phẩm bổ sung", icon: "leaf") }.buttonStyle(.plain)
            SectionHeading(title: "Món ăn gợi ý")
            Toggle("Chỉ xem món đã lưu", isOn: $savedOnly)
            ForEach(foods) { food in
                NavigationLink { FoodDetail(food: food) } label: { MomiCard { Label(food.name, systemImage: food.symbol).font(.headline); Text(food.nutrients).font(.subheadline).foregroundStyle(MomiTheme.muted) } }.buttonStyle(.plain)
            }
            Text("Bộ lọc dựa trên nguyên liệu chính của món mẫu. Kiểm tra nhãn và toàn bộ nguyên liệu trước khi ăn.").font(.footnote).foregroundStyle(MomiTheme.muted)
            SectionHeading(title: "Kế hoạch ăn")
            DatePicker("Chọn ngày", selection: $selectedDay, displayedComponents: .date)
            ForEach(store.snapshot.meals.filter { $0.day == Day.key(selectedDay) }) { entry in
                if let food = ContentLibrary.foods.first(where: { $0.id == entry.foodID }) {
                    HStack { Text(food.name); Spacer(); Button("Bỏ") { _ = store.commit { $0.meals.removeAll { $0.id == entry.id } } } }
                }
            }
        }.navigationTitle("Dinh dưỡng").sheet(isPresented: $preferences) { NavigationStack { FoodPreferencesView() } }
    }
}
struct FoodPreferencesView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var vegetarian = false
    @State private var allergies = Set<String>()
    var body: some View {
        Form {
            Toggle("Ưu tiên món chay có trứng/sữa", isOn: $vegetarian)
            Section("Tránh nguyên liệu") { ForEach(["Đậu nành", "Cá", "Sữa", "Trứng"], id: \.self) { value in Toggle(value, isOn: Binding(get: { allergies.contains(value) }, set: { if $0 { allergies.insert(value) } else { allergies.remove(value) } })) } }
        }.navigationTitle("Sở thích ăn uống").momiForm()
            .onAppear { vegetarian = store.snapshot.profile.vegetarian; allergies = Set(store.snapshot.profile.allergies) }
            .editorToolbar(save: { if store.commit({ $0.profile.vegetarian = vegetarian; $0.profile.allergies = Array(allergies) }) { dismiss() } }, cancel: { dismiss() })
    }
}
struct FoodDetail: View {
    @Environment(AppStore.self) private var store
    var food: Food
    @State private var day = Date()
    @State private var added = false
    var body: some View {
        MomiPage {
            Image(systemName: food.symbol).font(.system(size: 55)).foregroundStyle(MomiTheme.green).accessibilityHidden(true)
            Text(food.name).font(.largeTitle.bold()); Text(food.nutrients).foregroundStyle(MomiTheme.green)
            MomiCard { Text("Gợi ý chuẩn bị").font(.headline); Text(food.preparation); if !food.allergens.isEmpty { Text("Có: " + food.allergens.joined(separator: ", ")).font(.subheadline) } }
            Button(store.snapshot.savedFoods.contains(food.id) ? "Bỏ lưu món" : "Lưu món", systemImage: "bookmark") { _ = store.commit { if $0.savedFoods.contains(food.id) { $0.savedFoods.removeAll { $0 == food.id } } else { $0.savedFoods.append(food.id) } } }.buttonStyle(.bordered)
            DatePicker("Thêm vào ngày", selection: $day, displayedComponents: .date)
            PrimaryButton(title: added ? "Đã thêm vào kế hoạch" : "Thêm vào kế hoạch ăn") {
                added = store.commit { s in if !s.meals.contains(where: { $0.day == Day.key(day) && $0.foodID == food.id }) { s.meals.append(MealPlanEntry(day: Day.key(day), foodID: food.id)) } }
            }
        }.navigationTitle("Món ăn")
    }
}
