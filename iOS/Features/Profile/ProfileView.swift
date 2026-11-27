import SwiftUI

struct ProfileView: View {
    @Environment(TravelStore.self) private var store
    @State private var welcome = false
    let catalog: Catalog

    private var saved: [Destination] { catalog.attractions.filter { store.favorites.contains($0.id) } }

    var body: some View {
        YutoPage {
            HStack {
                YutoScreenTitle(title: "我的")
                NavigationLink { ProfileSettingsView() } label: {
                    Image(systemName: "gearshape").font(.title3)
                        .frame(width: 44, height: 44).background(YutoTheme.porcelain, in: Circle())
                }.accessibilityLabel("显示与隐私设置")
            }
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Group {
                        if store.profile.nickname.isEmpty {
                            Image("TravelEmblem").resizable().scaledToFit()
                        } else {
                            Text(String(store.profile.nickname.prefix(1))).font(.largeTitle.weight(.medium))
                                .foregroundStyle(YutoTheme.sage)
                        }
                    }.frame(width: 66, height: 66).background(YutoTheme.mist, in: Circle()).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.profile.nickname.isEmpty ? "悠途旅行者" : store.profile.nickname).font(.title2.bold())
                        NavigationLink("编辑旅行画像") { ProfilePreferencesView() }.font(.subheadline)
                    }
                }
                Divider()
                HStack(alignment: .top) {
                    metric(store.trips.filter(\.complete).count, "完成行程")
                    metric(store.favorites.count, "收藏目的地")
                    metric(store.companions.count, "常用同行人")
                }
            }.travelPanel()
            VStack(alignment: .leading, spacing: 14) {
                Text("旅行画像").font(.headline)
                NavigationLink { ProfilePreferencesView() } label: {
                    TravelMenuRow(icon: "slider.horizontal.3", title: "我的旅行偏好", detail: "称呼、步行能力与旅行节奏")
                }.buttonStyle(.plain).accessibilityIdentifier("profile-preferences")
                Divider()
                NavigationLink { SavedPlacesView(catalog: catalog) } label: {
                    TravelMenuRow(icon: "heart", title: "我的收藏", detail: "再看看那些想去的地方")
                }.buttonStyle(.plain).accessibilityIdentifier("profile-saved")
                Divider()
                NavigationLink { CompanionsView() } label: {
                    TravelMenuRow(icon: "person.2", title: "常用出行人", detail: "家人、朋友与同行旅伴")
                }.buttonStyle(.plain)
            }.travelPanel()
            NavigationLink { TravelHelpView() } label: {
                TravelMenuRow(icon: "phone.bubble", title: "出行求助", detail: "拨打已存号码，分享我的位置").travelPanel()
            }.buttonStyle(.plain)
            if !saved.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("收藏的目的地").font(.headline)
                    ForEach(saved.prefix(3)) { place in DestinationLink(place: place) }
                }
            }
            Button { welcome = true } label: {
                TravelMenuRow(icon: "sun.horizon", title: "关于悠途", detail: "打开悠途欢迎页").travelPanel()
            }.buttonStyle(.plain)
        }
        .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $welcome) { WelcomeView { welcome = false } }
    }

    private func metric(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .number).font(.title2.weight(.semibold).monospacedDigit())
            Text(label).foregroundStyle(YutoTheme.muted).font(.subheadline)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}

struct ProfilePreferencesView: View {
    @Environment(TravelStore.self) private var store
    var body: some View {
        @Bindable var store = store
        Form {
            Section("我的资料") {
                LabeledContent("昵称") {
                    TextField("姓名或昵称", text: $store.profile.nickname)
                        .multilineTextAlignment(.trailing)
                }
                Picker("年龄区间", selection: $store.profile.age) {
                    ForEach(["暂不填写", "55岁以下", "55–64岁", "65–74岁", "75岁及以上"], id: \.self) { Text($0) }
                }
            }.listRowBackground(YutoTheme.porcelain)
            Section {
                Toggle("需要轮椅辅助", isOn: $store.profile.wheelchair)
                Toggle("偏好短距离步行", isOn: $store.profile.shortWalk)
                Toggle("需要常休息", isOn: $store.profile.restOften)
                Toggle("偏好轻松节奏", isOn: $store.profile.slowPace)
            } header: { Text("出行习惯") } footer: {
                Text("这些偏好保存在本机，帮您匹配目的地和安排行程。")
            }.listRowBackground(YutoTheme.porcelain)
            Section {
                Picker("饮食偏好", selection: Binding(
                    get: { store.profile.dietPreference ?? "无特别偏好" },
                    set: { store.profile.dietPreference = $0 }
                )) {
                    ForEach(["无特别偏好", "清淡", "软食", "素食"], id: \.self) { Text($0) }
                }
                TextField("其他出行需要（选填）", text: Binding(
                    get: { store.profile.mobilityNote ?? "" },
                    set: { store.profile.mobilityNote = String($0.prefix(240)) }
                ), axis: .vertical).lineLimit(1...4)
            } header: { Text("饮食与照护") } footer: {
                Text("可记下希望家人协助的事项。这些信息只保存在本机。")
            }.listRowBackground(YutoTheme.porcelain)
        }.scrollContentBackground(.hidden).background(YutoTheme.paper)
        .navigationTitle("我的旅行偏好").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct ProfileSettingsView: View {
    @Environment(TravelStore.self) private var store
    @State private var clear = false
    var body: some View {
        @Bindable var store = store
        Form {
            Section("阅读与显示") {
                Picker("文字大小", selection: Binding(
                    get: { store.profile.extraLargeText == true ? 2 : store.profile.largerText ? 1 : 0 },
                    set: { size in
                        store.profile.extraLargeText = size == 2
                        store.profile.largerText = size >= 1
                    }
                )) {
                    Text("跟随系统").tag(0)
                    Text("大字").tag(1)
                    Text("特大字").tag(2)
                }
                Toggle("高对比度", isOn: Binding(get: { store.profile.highContrast == true }, set: { store.profile.highContrast = $0 }))
                Toggle("显示朗读按钮", isOn: Binding(get: { store.profile.readAloud ?? true }, set: { store.profile.readAloud = $0 }))
                TravelReadButton(text: "这是悠途的中文朗读。您可以在景区详情和行程中点按朗读。")
            }
            NavigationLink("图片授权") { PhotoLicensesView() }
            Button("清除旅行画像与联系人", role: .destructive) { clear = true }
        }.scrollContentBackground(.hidden).background(YutoTheme.paper)
        .navigationTitle("显示与隐私").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("清除旅行画像与本机求助联系人？", isPresented: $clear) {
            Button("清除", role: .destructive) { store.profile = Profile() }
            Button("取消", role: .cancel) {}
        }
    }
}

private struct SavedPlacesView: View {
    @Environment(TravelStore.self) private var store
    let catalog: Catalog
    var body: some View {
        let saved = catalog.attractions.filter { store.favorites.contains($0.id) }
        YutoPage {
            if saved.isEmpty {
                ContentUnavailableView("收藏想去的地方", systemImage: "heart", description: Text("点一下景区上的爱心，就可以在这里找到它。"))
            }
            ForEach(saved) { place in DestinationLink(place: place) }
        }.navigationTitle("我的收藏").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct PhotoLicensesView: View {
    var body: some View {
        List {
            Section("旅行插画") {
                Text("欢迎页、推荐封面和规划师形象为悠途的 AI 生成插画。下列摄影作品用于景区详情与相册。")
            }
            credit("杭州西湖", author: "Louisa Salazar", file: "File:West_Lake_-_Hangzhou,_China.jpg",
                   license: "CC BY-SA 3.0", licensePath: "by-sa/3.0")
            credit("苏州拙政园", author: "Ray in Manila", file: "File:The_Humble_Administrator's_Garden,_Suzhou,_China_(37825378061).jpg",
                   license: "CC BY 2.0", licensePath: "by/2.0")
            credit("鼓浪屿", author: "Rolfmueller", file: "File:Gulangyu_sunlight_rock_2011_12.jpg",
                   license: "CC BY-SA 3.0", licensePath: "by-sa/3.0")
        }.navigationTitle("图片授权")
    }

    private func credit(_ title: String, author: String, file: String, license: String, licensePath: String) -> some View {
        Section(title) {
            Text("摄影：\(author) · 已缩放，卡片中裁切呈现")
            if let original = URL(string: "https://commons.wikimedia.org/wiki/" + file) {
                Link("原始照片", destination: original)
            }
            if let licenseURL = URL(string: "https://creativecommons.org/licenses/" + licensePath + "/") {
                Link(license, destination: licenseURL)
            }
        }
    }
}
