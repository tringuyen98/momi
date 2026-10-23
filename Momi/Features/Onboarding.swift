import SwiftUI
import MomiCore

struct OnboardingDraft {
    var name = ""
    var stage: Stage = .preparation
    var hasPeriodDate = false
    var periodDate = Date()
    var hasDueDate = false
    var dueDate = Date()
}

struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isPreview = false
    var onClose: (() -> Void)?
    var onBegin: (OnboardingDraft) -> Bool
    @State private var draft = OnboardingDraft()
    @State private var appeared = false
    @State private var starting = false
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var showingDateEditor = false
    @FocusState private var nameFocused: Bool
    @State private var editedDate = Date()
    private var accent: Color { draft.stage == .pregnant ? MomiTheme.rose : MomiTheme.green }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                // Keep the same TextField mounted when the keyboard changes the available height.
                welcomeContent(compact: geometry.size.height < 620,
                               minimal: nameFocused || geometry.size.height < 460 || dynamicType.isAccessibilitySize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                LinearGradient(colors: [Color(red: 0.98, green: 0.97, blue: 0.94), MomiTheme.background, Color(red: 0.91, green: 0.94, blue: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { startButton }
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Xong") { nameFocused = false }
                }
            }
            .sheet(isPresented: $showingDateEditor) { dateEditor }
            .onAppear { appeared = true }
            .sensoryFeedback(.selection, trigger: draft.stage)
        }
    }
    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "leaf.fill").font(.subheadline).rotationEffect(.degrees(-25))
                Text("momi").font(.system(.title2, design: .serif).weight(.semibold)).tracking(-0.6)
            }.foregroundStyle(MomiTheme.green).accessibilityLabel("Momi")
            Spacer()
            if isPreview {
                Button("Đóng") { onClose?() }.font(.subheadline).foregroundStyle(MomiTheme.muted)
            } else {
                Text("CÙNG BẠN, TỪ ĐẦU").font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(1.4).foregroundStyle(MomiTheme.green.opacity(0.75))
            }
        }
    }
    private func welcomeContent(compact: Bool, minimal: Bool) -> some View {
        VStack(spacing: compact ? 12 : 20) {
            topBar.entrance(appeared, delay: 0, reduceMotion: reduceMotion)
            if !minimal {
                hero(compact: compact).entrance(appeared, delay: 0.07, reduceMotion: reduceMotion)
            }
            profileCard(minimal: minimal).entrance(appeared, delay: 0.17, reduceMotion: reduceMotion)
            if !minimal {
                Label("Riêng tư trên iPhone của bạn", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(MomiTheme.muted)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, compact ? 8 : 12)
        .frame(maxWidth: 540).fixedSize(horizontal: false, vertical: true)
    }
    private func hero(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            MomiBloom().frame(height: compact ? 64 : 120).accessibilityHidden(true)
            VStack(spacing: 2) {
                Text("Một hành trình mới,").foregroundStyle(MomiTheme.ink)
                Text("có Momi bên mình.").foregroundStyle(MomiTheme.green)
            }.font(.system(compact ? .title2 : .title, design: .serif).weight(.medium)).tracking(-0.8)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            if !compact {
                Text("Một chút chuẩn bị. Một chút an tâm.")
                    .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(MomiTheme.muted)
            }
        }.frame(maxWidth: .infinity)
    }
    private func profileCard(minimal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle").foregroundStyle(accent).accessibilityHidden(true)
                TextField("Momi gọi bạn là gì?", text: $draft.name)
                    .font(.subheadline).foregroundStyle(MomiTheme.ink)
                    .textContentType(.givenName).textInputAutocapitalization(.words)
                    .autocorrectionDisabled().submitLabel(.done).focused($nameFocused)
                    .onSubmit { nameFocused = false }
                    .accessibilityLabel("Tên thân mật, có thể để trống")
            }
            .padding(.horizontal, 12).frame(minHeight: 48)
            .background(MomiTheme.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(nameFocused ? accent.opacity(0.65) : MomiTheme.border, lineWidth: 1)
            }
            Divider().overlay(MomiTheme.border.opacity(0.4))
            if minimal || dynamicType.isAccessibilitySize {
                Menu {
                    Button("Chuẩn bị có em bé") { draft.stage = .preparation }
                    Button("Đang mang thai") { draft.stage = .pregnant }
                } label: {
                    detailRow(title: draft.stage.title, icon: draft.stage == .pregnant ? "heart" : "leaf")
                }.accessibilityLabel("Giai đoạn: \(draft.stage.title)")
            } else {
                EqualStageCardsLayout(spacing: 10) { stageCard(.preparation); stageCard(.pregnant) }
            }
            Button {
                editedDate = draft.stage == .pregnant ? draft.dueDate : draft.periodDate
                nameFocused = false
                showingDateEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    detailRow(title: draft.stage == .pregnant ? "Ngày dự sinh" : "Kỳ kinh gần nhất", icon: "calendar")
                    if dateEnabled.wrappedValue {
                        Text((draft.stage == .pregnant ? draft.dueDate : draft.periodDate).formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline).foregroundStyle(accent)
                    } else if !minimal {
                        Text("Chưa nhớ? Mình thêm sau nhé.").font(.caption).foregroundStyle(MomiTheme.muted)
                    }
                }
            }.accessibilityHint("Mở bảng chọn ngày")
        }.buttonStyle(.plain).padding(16)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 27))
            .overlay { RoundedRectangle(cornerRadius: 27).stroke(.white.opacity(0.95), lineWidth: 1) }
            .shadow(color: MomiTheme.green.opacity(0.045), radius: 20, x: 0, y: 8)
    }
    private func detailRow(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(accent).accessibilityHidden(true)
            Text(title).foregroundStyle(MomiTheme.ink)
                .multilineTextAlignment(.leading).lineLimit(2)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(MomiTheme.muted).accessibilityHidden(true)
        }.font(.subheadline.weight(.medium)).frame(minHeight: 44).contentShape(Rectangle())
    }
    private var dateEditor: some View {
        NavigationStack {
            Form {
                Section {
                    if draft.stage == .pregnant {
                        DatePicker("Ngày dự sinh", selection: $editedDate, displayedComponents: .date)
                    } else {
                        DatePicker("Ngày bắt đầu kỳ kinh", selection: $editedDate, in: ...Date(), displayedComponents: .date)
                    }
                } footer: {
                    Text("Bạn có thể cập nhật lại trong Cài đặt bất cứ lúc nào.")
                }
                Section {
                    Button(dateEnabled.wrappedValue ? "Bỏ ngày đã chọn" : "Để sau") {
                        dateEnabled.wrappedValue = false
                        showingDateEditor = false
                    }
                }
                if isPreview {
                    Section { Text("Đang xem thử. Thông tin không được lưu vào hồ sơ.").foregroundStyle(MomiTheme.muted) }
                }
            }
            .navigationTitle("Thêm ngày")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { showingDateEditor = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") {
                        if draft.stage == .pregnant { draft.dueDate = editedDate }
                        else { draft.periodDate = min(editedDate, Date()) }
                        dateEnabled.wrappedValue = true
                        showingDateEditor = false
                    }
                }
            }
            .tint(accent)
        }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    private func stageCard(_ stage: Stage) -> some View {
        let selected = draft.stage == stage
        let color = stage == .pregnant ? MomiTheme.rose : MomiTheme.green
        return Button {
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.8)) { draft.stage = stage }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: stage == .pregnant ? "heart.fill" : "leaf.fill").font(.title3)
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.subheadline).opacity(selected ? 1 : 0.35)
                }.foregroundStyle(color)
                Text(stage == .pregnant ? "Đang mang thai" : "Chuẩn bị có em bé").font(.subheadline.weight(.semibold)).foregroundStyle(MomiTheme.ink).fixedSize(horizontal: false, vertical: true)
            }.padding(13).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(selected ? color.opacity(0.085) : MomiTheme.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(selected ? color.opacity(0.65) : MomiTheme.border, lineWidth: selected ? 1.5 : 1) }
        }.buttonStyle(MomiPressStyle()).accessibilityLabel(stage.title)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var dateEnabled: Binding<Bool> {
        Binding(get: { draft.stage == .pregnant ? draft.hasDueDate : draft.hasPeriodDate }, set: { value in
            if draft.stage == .pregnant { draft.hasDueDate = value } else { draft.hasPeriodDate = value }
        })
    }
    private var startButton: some View {
        VStack(spacing: 9) {
            Button {
                guard !starting else { return }
                nameFocused = false
                starting = onBegin(draft)
            } label: {
                HStack(spacing: 12) {
                    Text("Bắt đầu cùng Momi").font(.headline)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right").font(.body.weight(.semibold))
                        .frame(width: 32, height: 32).background(.white.opacity(0.14), in: Circle())
                }.foregroundStyle(.white).padding(.horizontal, 22).padding(.vertical, 13)
                    .background(LinearGradient(colors: [MomiTheme.green, Color(red: 0.22, green: 0.36, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
                    .shadow(color: MomiTheme.green.opacity(0.18), radius: 12, x: 0, y: 6)
            }.buttonStyle(MomiPressStyle()).disabled(starting)
            Text(isPreview ? "Đang xem thử · Không lưu vào hồ sơ" : "Không cần hoàn hảo. Chỉ cần bắt đầu.").font(.caption).foregroundStyle(MomiTheme.muted)
        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10)
            .frame(maxWidth: 540).frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .entrance(appeared, delay: 0.28, reduceMotion: reduceMotion)
    }
}

/// Measure both labels at the same width, then give both cards the taller height.
private struct EqualStageCardsLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let columnWidth = max(0, (width - spacing) / 2)
        let height = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
        }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columnWidth = max(0, (bounds.width - spacing) / 2)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + CGFloat(index) * (columnWidth + spacing), y: bounds.minY),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: columnWidth, height: bounds.height))
        }
    }
}

struct MomiBloom: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var breathing = false
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.height, 175)
            ZStack {
                Circle().fill(RadialGradient(colors: [MomiTheme.green.opacity(0.10), .clear], center: .center, startRadius: 10, endRadius: size * 0.6)).frame(width: size * 1.5, height: size * 1.5)
                Ellipse().fill(MomiTheme.green.opacity(0.10)).frame(width: size * 0.6, height: size * 0.86).rotationEffect(.degrees(-38)).offset(x: -size * 0.18, y: -size * 0.08)
                Ellipse().fill(MomiTheme.rose.opacity(0.12)).frame(width: size * 0.55, height: size * 0.82).rotationEffect(.degrees(37)).offset(x: size * 0.18, y: -size * 0.07)
                Circle().stroke(MomiTheme.green.opacity(0.13), lineWidth: 1).frame(width: size * 0.9, height: size * 0.9)
                Circle().fill(LinearGradient(colors: [MomiTheme.green.opacity(0.93), Color(red: 0.22, green: 0.36, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size * 0.65, height: size * 0.65)
                    .shadow(color: MomiTheme.green.opacity(0.16), radius: 16, x: 0, y: 9)
                Image(systemName: "leaf.fill").font(.system(size: size * 0.30, weight: .light)).foregroundStyle(MomiTheme.card).rotationEffect(.degrees(-25))
                Image(systemName: "heart.fill").font(.system(size: size * 0.085)).foregroundStyle(MomiTheme.rose)
                    .frame(width: size * 0.25, height: size * 0.25).background(MomiTheme.card, in: Circle())
                    .overlay { Circle().stroke(MomiTheme.border.opacity(0.7), lineWidth: 1) }.offset(x: size * 0.35, y: size * 0.24)
                Circle().fill(MomiTheme.green.opacity(0.35)).frame(width: 6, height: 6).offset(x: -size * 0.42, y: size * 0.23)
                Image(systemName: "sparkle").font(.system(size: 13, weight: .light)).foregroundStyle(MomiTheme.rose.opacity(0.65)).offset(x: size * 0.4, y: -size * 0.32)
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(breathing && !reduceMotion ? 1.035 : 1)
                .rotationEffect(.degrees(breathing && !reduceMotion ? 2 : -1))
                .animation(!reduceMotion && scenePhase == .active ? .easeInOut(duration: 4).repeatForever(autoreverses: true) : nil, value: breathing)
        }.onAppear { breathing = !reduceMotion }
            .onChange(of: scenePhase) { _, phase in breathing = phase == .active && !reduceMotion }
            .onChange(of: reduceMotion) { _, reduced in breathing = !reduced }
    }
}

struct MomiEntranceOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var name: String
    var onCovered: () -> Void
    var onReveal: () -> Void
    var onFinished: () -> Void
    @State private var expanded = false
    @State private var brandVisible = false
    @State private var fading = false
    var body: some View {
        GeometryReader { geometry in
            let diameter = hypot(geometry.size.width, geometry.size.height) * 2.2
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(red: 0.89, green: 0.93, blue: 0.86), MomiTheme.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(reduceMotion || expanded ? 1 : 0.001)
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 70)
                VStack(spacing: 16) {
                    MomiBloom().frame(width: 170, height: 170)
                    Text("momi").font(.system(size: 52, weight: .medium, design: .serif)).tracking(-2).foregroundStyle(MomiTheme.green)
                    Text(name.isEmpty ? "Mình bắt đầu nhé." : "Mình bắt đầu nhé, \(name).")
                        .font(.title3.weight(.medium)).multilineTextAlignment(.center).foregroundStyle(MomiTheme.ink)
                    Text("Từng chút an tâm, mỗi ngày.").font(.subheadline).foregroundStyle(MomiTheme.muted)
                }.padding(30).frame(maxWidth: 480).frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(brandVisible ? 1 : 0)
                    .scaleEffect(reduceMotion || brandVisible ? 1 : 0.94)
                    .offset(y: reduceMotion || brandVisible ? 0 : 16)
                    .accessibilityElement(children: .combine)
            }.opacity(fading ? 0 : 1)
        }.ignoresSafeArea().clipped().allowsHitTesting(true)
            .task {
                // Mount the initial iris before starting its expansion.
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
                if reduceMotion {
                    expanded = true; brandVisible = true
                    onCovered()
                    do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                } else {
                    withAnimation(.easeInOut(duration: 0.62)) { expanded = true }
                    do { try await Task.sleep(for: .milliseconds(630)) } catch { return }
                    onCovered()
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.85)) { brandVisible = true }
                    do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
                }
                guard !Task.isCancelled else { return }
                onReveal()
                withAnimation(.easeInOut(duration: reduceMotion ? 0.22 : 0.6)) { fading = true }
                do { try await Task.sleep(for: .milliseconds(reduceMotion ? 230 : 610)) } catch { return }
                onFinished()
            }
    }
}

private struct MomiPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
private extension View {
    func entrance(_ visible: Bool, delay: Double, reduceMotion: Bool) -> some View {
        opacity(visible ? 1 : 0).offset(y: visible || reduceMotion ? 0 : 14)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.7, dampingFraction: 0.86).delay(delay), value: visible)
    }
}
