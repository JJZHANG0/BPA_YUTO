import SwiftUI

struct FootprintsView: View {
    let catalog: Catalog
    @Environment(TravelStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selection: String?
    @State private var command: ProvinceCameraCommand?
    @State private var picker: FootprintListFilter?
    @State private var showingMemory = false
    @State private var lastMark: Date?

    private var visited: Set<String> { store.visitedProvinces(in: catalog) }
    private var province: String {
        selection ?? catalog.provinces.first(where: visited.contains)
            ?? (catalog.provinces.contains("浙江") ? "浙江" : catalog.provinces.first ?? "")
    }

    var body: some View {
        GeometryReader { proxy in
            let fits = !typeSize.isAccessibilitySize && proxy.size.height >= 490
            Group {
                if fits {
                    footprintPage(mapHeight: nil)
                } else {
                    ScrollView {
                        footprintPage(mapHeight: min(280, max(156, proxy.size.height * 0.48)))
                    }
                }
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(YutoTheme.paper)
        .foregroundStyle(YutoTheme.ink)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("点亮中国")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(YutoTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("footprints-title")
                    if typeSize <= .xLarge {
                        Text("记录你走过的每一片土地")
                            .font(.caption).foregroundStyle(YutoTheme.muted)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("分享我的点亮进度")
            }
        }
        .sheet(item: $picker) { filter in
            FootprintProvinceList(provinces: catalog.provinces, visited: visited, initialFilter: filter) { name in
                selection = name
                picker = nil
            }
        }
        .sheet(isPresented: $showingMemory) {
            ProvinceMemoryView(province: province, catalog: catalog)
        }
    }

    private func footprintPage(mapHeight: CGFloat?) -> some View {
        VStack(spacing: 9) {
            progress.padding(.horizontal, 16)
            map(mapHeight)
            if !province.isEmpty { selectedCard.padding(.horizontal, 16) }
            Button { picker = .visited } label: {
                Label("查看旅行足迹", systemImage: "shoeprints.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(YutoButtonStyle())
            .accessibilityIdentifier("footprint-visited-list")
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var shareText: String {
        let names = catalog.provinces.filter(visited.contains)
        let summary = "我在悠途点亮了 \(names.count)/\(catalog.provinces.count) 个省级地区。"
        return names.isEmpty ? summary : summary + "\n我的足迹：" + names.joined(separator: "、")
    }

    private var progress: some View {
        let percent = catalog.provinces.isEmpty ? 0 : Int((100.0 * Double(visited.count) / Double(catalog.provinces.count)).rounded())
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                                                  : AnyLayout(HStackLayout(spacing: 15))
        return layout {
            HStack(spacing: 10) {
                Image(systemName: "mountain.2.fill")
                    .font(.title2).foregroundStyle(YutoTheme.sage)
                    .padding(8).background(YutoTheme.mist, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("已点亮省份").font(.subheadline).foregroundStyle(YutoTheme.muted)
                        .fixedSize(horizontal: true, vertical: false)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(visited.count)").font(.title.bold().monospacedDigit())
                        Text("/ \(catalog.provinces.count)").font(.headline.monospacedDigit())
                    }.fixedSize(horizontal: true, vertical: false)
                }
            }.fixedSize(horizontal: true, vertical: false)
            if !typeSize.isAccessibilitySize {
                Rectangle().fill(YutoTheme.divider).frame(width: 1, height: 38)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("点亮进度").font(.subheadline).foregroundStyle(YutoTheme.muted)
                Text("\(percent)%").font(.headline.monospacedDigit())
                ProgressView(value: Double(percent), total: 100)
                    .tint(YutoTheme.sage)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .travelPanel(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("点亮进度")
        .accessibilityValue("已点亮 \(visited.count) 个，共 \(catalog.provinces.count) 个，百分之\(percent)")
        .accessibilityIdentifier("footprint-progress")
    }

    private func map(_ height: CGFloat?) -> some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack { legend; Spacer(); listButton }
                VStack(spacing: 0) { legend; listButton }
            }
            .padding(.horizontal, 18)
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: height == nil ? .infinity : height)
                .frame(height: height)
                .overlay {
                    ProvinceScene(visited: visited, selected: province, cameraCommand: command) { name in
                        if catalog.provinces.contains(name) { selection = name }
                    }
                }
                .background(RadialGradient(colors: [YutoTheme.greyGreen.opacity(0.56), YutoTheme.paper],
                                           center: .center, startRadius: 0, endRadius: 240))
                .clipped()
                .padding(.horizontal, height == nil ? 0 : 18)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) { gestureHint; Spacer(); controls }
                VStack(alignment: .leading, spacing: 4) { gestureHint; controls }
            }
            .padding(.horizontal, 18)
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            Label("已点亮", systemImage: "sun.max.fill").foregroundStyle(YutoTheme.amberInk)
            Label("未点亮", systemImage: "circle.dashed").foregroundStyle(YutoTheme.muted)
        }.font(.subheadline)
    }

    private var listButton: some View {
        Button { picker = .all } label: {
            Label("选择省份", systemImage: "list.bullet")
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }.accessibilityIdentifier("footprint-provinces")
    }

    private var gestureHint: some View {
        Text("拖动旋转 · 双指缩放")
            .font(.footnote).foregroundStyle(YutoTheme.muted)
    }

    private var controls: some View {
        HStack(spacing: 1) {
            cameraButton(.zoomOut, symbol: "minus", label: "缩小地图")
            cameraButton(.zoomIn, symbol: "plus", label: "放大地图")
            cameraButton(.reset, symbol: "arrow.counterclockwise", label: "回到全图")
        }
        .background(YutoTheme.porcelain, in: Capsule())
        .overlay { Capsule().strokeBorder(YutoTheme.divider).allowsHitTesting(false) }
    }

    private func cameraButton(_ action: ProvinceCameraCommand.Action, symbol: String, label: String) -> some View {
        Button {
            command = ProvinceCameraCommand(action: action)
        } label: {
            Image(systemName: symbol).font(.body.weight(.medium))
                .frame(width: 44, height: 44)
        }.accessibilityLabel(label)
    }

    private var selectedCard: some View {
        let lit = visited.contains(province)
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                                  : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            Button { showingMemory = true } label: {
                HStack(spacing: 10) {
                    let image = ProvinceIllustration.photo(for: province)
                    YutoPhoto(name: image.name, subdirectory: image.folder)
                        .frame(width: 68, height: 55)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(province).font(.title3.bold())
                        Label(lit ? "已点亮 · 旅行记忆" : "旅行记忆", systemImage: lit ? "sun.max.fill" : "book")
                            .font(.footnote).foregroundStyle(lit ? YutoTheme.amberInk : YutoTheme.muted)
                    }
                    Spacer(minLength: 1)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(YutoTheme.muted)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("查看\(province)的旅行记忆")
                .accessibilityIdentifier("footprint-memory")
            if !lit {
                Button {
                    store.markProvince(province)
                    lastMark = .now
                } label: {
                    Label("点亮", systemImage: "sun.max.fill")
                        .font(.subheadline.bold()).fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .foregroundStyle(YutoTheme.amberInk)
                        .background(YutoTheme.amberSurface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("我去过，点亮\(province)")
                .accessibilityIdentifier("footprint-mark")
            }
        }
        .travelPanel(10)
        .sensoryFeedback(.success, trigger: lastMark)
    }
}

private enum FootprintListFilter: String, CaseIterable, Identifiable {
    case all = "全部省份", visited = "已点亮"
    var id: Self { self }
}

private struct FootprintProvinceList: View {
    let provinces: [String]
    let visited: Set<String>
    let select: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var filter: FootprintListFilter

    init(provinces: [String], visited: Set<String>, initialFilter: FootprintListFilter, select: @escaping (String) -> Void) {
        self.provinces = provinces
        self.visited = visited
        self.select = select
        _filter = State(initialValue: initialFilter)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                Picker("显示省份", selection: $filter) {
                    ForEach(FootprintListFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal, 18)
                if filter == .visited && visited.isEmpty {
                    ContentUnavailableView {
                        Label("第一枚足迹，等你点亮", systemImage: "shoeprints.fill")
                    } description: {
                        Text("选一个去过的省份，或者把行程标记为已完成。")
                    } actions: {
                        Button("选择省份") { filter = .all }.buttonStyle(YutoButtonStyle())
                    }
                } else {
                    List {
                        ForEach(provinces.filter { filter == .all || visited.contains($0) }, id: \.self) { item in
                            Button { select(item) } label: {
                                HStack {
                                    Text(item).font(.headline)
                                    Spacer()
                                    Label(visited.contains(item) ? "已点亮" : "未点亮",
                                          systemImage: visited.contains(item) ? "sun.max.fill" : "circle.dashed")
                                        .font(.subheadline)
                                        .foregroundStyle(visited.contains(item) ? YutoTheme.amberInk : YutoTheme.muted)
                                }.frame(minHeight: 44).contentShape(Rectangle())
                            }
                            .foregroundStyle(YutoTheme.ink)
                            .accessibilityIdentifier("footprint-select-\(item)")
                            .listRowBackground(YutoTheme.porcelain)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(YutoTheme.paper)
            .navigationTitle("旅行足迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
