import SwiftUI

struct FamilyView: View {
    @Environment(TravelStore.self) private var store
    @Environment(TripPresentation.self) private var presentation
    @State private var selection: UUID?
    @State private var adding = false
    let catalog: Catalog

    private var trip: Trip? { store.trips.first { $0.id == selection } ?? store.trips.first }

    var body: some View {
        YutoPage {
            YutoScreenTitle(title: "家人协作")
            if let trip {
                VStack(alignment: .trailing, spacing: 4) {
                    let place = catalog.destination(trip.destination)
                    TravelCover(place: place, title: "\(place?.shortName ?? "我们的")家庭游",
                                subtitle: trip.displayDates + "  ·  共\(trip.days)天")
                    if store.trips.count > 1 {
                        Menu {
                            ForEach(store.trips) { item in
                                Button("\(catalog.destination(item.destination)?.shortName ?? "行程") · \(item.displayDates)") { selection = item.id }
                            }
                        } label: { Label("切换行程", systemImage: "arrow.left.arrow.right").frame(minHeight: 44) }
                    }
                }
            } else {
                TravelCover(place: nil, title: "和家人一起出发", subtitle: "一起商量下一站，把想法记下来。")
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("常用同行人").font(.headline)
                    Spacer()
                    NavigationLink("管理") { CompanionsView() }.font(.subheadline).frame(minHeight: 44)
                }
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        VStack {
                            CompanionAvatar(name: store.profile.nickname.isEmpty ? "我" : store.profile.nickname, warm: true)
                            Text("我").font(.subheadline)
                        }
                        ForEach(store.companions) { person in
                            VStack {
                                CompanionAvatar(name: person.name)
                                Text(person.name).font(.subheadline).lineLimit(1)
                            }.frame(maxWidth: 88)
                        }
                        Button { adding = true } label: {
                            VStack {
                                Image(systemName: "plus").frame(width: 48, height: 48)
                                    .background(YutoTheme.mist, in: Circle())
                                Text("添加").font(.subheadline)
                            }
                        }.accessibilityLabel("添加同行人")
                    }.padding(.vertical, 2)
                }.scrollIndicators(.hidden)
            }.travelPanel()
            NavigationLink { TravelHelpView() } label: {
                TravelMenuRow(icon: "phone.bubble", title: "出行求助", detail: "联系家人、导游或服务方").travelPanel()
            }.buttonStyle(.plain)
            if let trip {
                VStack(spacing: 14) {
                    Button { presentation.editing = trip } label: {
                        TravelMenuRow(icon: "square.and.pencil", title: "一起安排行程", detail: "调整出发日期、第一站和节奏")
                    }.buttonStyle(.plain)
                    Divider()
                    NavigationLink { FamilyNotesView(tripID: trip.id) } label: {
                        TravelMenuRow(icon: "bubble.left.and.bubble.right", title: "讨论与备忘", detail: "本机已记录 \(trip.familyNotes?.count ?? 0) 条想法")
                    }.buttonStyle(.plain).accessibilityIdentifier("family-notes")
                    Divider()
                    ShareLink(item: familySummary(trip)) {
                        TravelMenuRow(icon: "paperplane", title: "分享给家人", detail: "发送每日安排与出行备忘")
                    }.buttonStyle(.plain)
                }.travelPanel()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label("家庭旅行计划", systemImage: "calendar").font(.headline)
                    Text("先选好想去的地方，就能在这里记录家人的建议，分享每日安排。")
                        .font(.body).foregroundStyle(YutoTheme.muted)
                    Button {
                        if let place = catalog.attractions.first(where: { $0.featuredArtwork == "WestLake" }) ?? catalog.attractions.first {
                            presentation.editing = Trip(destination: place.id, slow: store.profile.slowPace)
                        }
                    } label: {
                        Label("创建家庭行程", systemImage: "plus").frame(maxWidth: .infinity)
                    }.buttonStyle(YutoButtonStyle())
                }.travelPanel()
            }
        }
        .navigationTitle("家人协作").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $adding) { AddCompanionView() }
    }

    private func familySummary(_ trip: Trip) -> String {
        let notes = (trip.familyNotes ?? []).map { "• " + $0.text }
        return ([trip.shareSummary(catalog: catalog)] + (notes.isEmpty ? [] : ["出行备忘"] + notes)).joined(separator: "\n")
    }
}

struct CompanionAvatar: View {
    let name: String
    var warm = false
    var body: some View {
        Text(String(name.prefix(1))).font(.title2.weight(.medium))
            .frame(width: 48, height: 48)
            .foregroundStyle(warm ? YutoTheme.amberInk : YutoTheme.sage)
            .background(warm ? YutoTheme.amberSurface : YutoTheme.mist, in: Circle())
            .accessibilityHidden(true)
    }
}

struct CompanionsView: View {
    @Environment(TravelStore.self) private var store
    @State private var adding = false
    @State private var removing: TravelCompanion?
    var body: some View {
        YutoPage {
            if store.companions.isEmpty {
                Label("记下常同行的家人，下次计划旅行时可以随时查看。", systemImage: "person.2")
                    .foregroundStyle(YutoTheme.muted).travelPanel()
            }
            ForEach(store.companions) { person in
                HStack {
                    CompanionAvatar(name: person.name)
                    VStack(alignment: .leading) {
                        Text(person.name).font(.headline)
                        Text(person.role).font(.subheadline).foregroundStyle(YutoTheme.muted)
                    }
                    Spacer()
                    Button { removing = person } label: {
                        Image(systemName: "minus.circle").frame(width: 44, height: 44)
                    }.accessibilityLabel("移除" + person.name)
                }.travelPanel()
            }
            Button { adding = true } label: {
                Label("添加同行人", systemImage: "person.badge.plus").frame(maxWidth: .infinity)
            }.buttonStyle(YutoButtonStyle())
        }.navigationTitle("常用同行人").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $adding) { AddCompanionView() }
        .confirmationDialog("移除这位同行人？", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), titleVisibility: .visible, presenting: removing) { person in
            Button("移除", role: .destructive) { store.removeCompanion(person.id) }
        }
    }
}

private struct AddCompanionView: View {
    @Environment(TravelStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var role = "家人"
    var body: some View {
        NavigationStack {
            Form {
                TextField("姓名或称呼", text: $name)
                Picker("关系", selection: $role) {
                    ForEach(["家人", "长辈", "朋友", "旅伴"], id: \.self) { Text($0) }
                }
            }.scrollContentBackground(.hidden).background(YutoTheme.paper)
            .navigationTitle("添加同行人").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { store.addCompanion(name: name, role: role); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 24)
                }
            }
        }.presentationDetents([.medium, .large])
    }
}

private struct FamilyNotesView: View {
    @Environment(TravelStore.self) private var store
    @State private var text = ""
    @State private var deleting: FamilyNote?
    @FocusState private var editing: Bool
    let tripID: UUID
    var body: some View {
        let notes = store.trips.first { $0.id == tripID }?.familyNotes ?? []
        YutoPage {
            VStack(alignment: .leading, spacing: 14) {
                Text("记下家人的想法").font(.headline)
                TextField("例如：午饭后想留一小时休息", text: $text, axis: .vertical)
                    .focused($editing).lineLimit(2...5).textFieldStyle(.roundedBorder).accessibilityIdentifier("family-note-input")
                Button("保存到本机") {
                    store.addFamilyNote(text, to: tripID)
                    text = ""; editing = false
                }.buttonStyle(YutoButtonStyle())
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 500)
            }.travelPanel()
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(note.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline).foregroundStyle(YutoTheme.muted)
                        Spacer()
                        Button { deleting = note } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                            .accessibilityLabel("删除备忘")
                    }
                    Text(note.text)
                }.travelPanel()
            }
        }.navigationTitle("讨论与备忘").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("删除这条备忘？", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible, presenting: deleting) { note in
            Button("删除", role: .destructive) { store.removeFamilyNote(note.id, from: tripID) }
        }
    }
}
