import SwiftUI

struct ProfileView: View {
    @Environment(TravelStore.self) private var store
    @State private var showClearProfile = false
    let catalog: Catalog

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                YutoScreenTitle(title: store.profile.nickname.isEmpty ? "我的悠途" : store.profile.nickname)
                    .padding(.vertical, 6)
            }.listRowBackground(YutoTheme.paper)
            Section {
                LabeledContent("昵称") {
                    TextField("昵称", text: $store.profile.nickname, prompt: Text("选填").foregroundStyle(YutoTheme.muted))
                        .multilineTextAlignment(.trailing)
                }
                Picker("年龄区间", selection: $store.profile.age) {
                    ForEach(["暂不填写", "55岁以下", "55–64岁", "65–74岁", "75岁及以上"], id: \.self) { Text($0) }
                }
                Toggle("需要轮椅辅助", isOn: $store.profile.wheelchair)
                Toggle("偏好短距离步行", isOn: $store.profile.shortWalk)
                Toggle("需要常休息", isOn: $store.profile.restOften)
                Toggle("偏好轻松节奏", isOn: $store.profile.slowPace)
            } header: { Text("旅行画像").foregroundStyle(YutoTheme.muted) } footer: {
                Text("您可跳过或随时修改。画像保存在此设备，用于匹配和安排行程。")
                    .foregroundStyle(YutoTheme.muted)
            }
            Section("显示与隐私") {
                Toggle("使用更大字号", isOn: $store.profile.largerText)
                Button("清除旅行画像", role: .destructive) { showClearProfile = true }
            }
            Section("收藏的目的地") {
                let saved = catalog.attractions.filter { store.favorites.contains($0.id) }
                if saved.isEmpty { Text("暂时没有收藏。") }
                ForEach(saved) { DestinationLink(place: $0) }
            }
            Section {
                NavigationLink("图片授权") { PhotoLicensesView() }
            }

        }
        .scrollContentBackground(.hidden)
        .background(YutoTheme.mist.ignoresSafeArea())
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .alert("清除旅行画像？", isPresented: $showClearProfile) {
            Button("清除", role: .destructive) { store.profile = Profile() }
            Button("取消", role: .cancel) {}
        }
    }
}


private struct PhotoLicensesView: View {
    var body: some View {
        List {
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
