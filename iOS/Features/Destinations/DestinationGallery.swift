import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct DestinationGallery: View {
    let place: Destination
    @State private var photoURLs: [URL] = []
    @State private var pendingPhoto: PhotosPickerItem?
    @State private var selected = 0
    @State private var showViewer = false
    @State private var photoError = false
    @State private var pendingRemoval: URL?

    private var bundledPhoto: URL? {
        guard let name = place.featuredArtwork else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "jpg")
    }

    private var pictures: [URL] { [bundledPhoto].compactMap { $0 } + photoURLs }

    private var folder: URL {
        DestinationAlbumFiles.folder(for: place.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Spacer(minLength: 180)
            Text(place.grade + " 级景区")
                .font(.subheadline.weight(.semibold))
            Text(place.featuredArtwork == nil ? place.name : place.shortName)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .accessibilityLabel(place.name)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .center, spacing: 8) {
                Text(heroCaption).font(.subheadline.weight(.medium))
                Spacer(minLength: 4)
                Button {
                    selected = 0
                    showViewer = true
                } label: {
                    Label("相册", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.black.opacity(0.4), in: Capsule())
                        .overlay { Capsule().strokeBorder(.white.opacity(0.65)) }
                        .frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityLabel("打开景区相册")
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .foregroundStyle(.white)
        .background {
            ZStack {
                if let first = pictures.first {
                    AlbumPhoto(url: first)
                } else {
                    let image = ProvinceIllustration.photo(for: place.province)
                    YutoPhoto(name: image.name, subdirectory: image.folder)
                }
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.26),
                    .init(color: .black.opacity(0.25), location: 0.58),
                    .init(color: .black.opacity(0.78), location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .task { reload() }
        .task(id: pendingPhoto) {
            guard let item = pendingPhoto else { return }
            defer { if !Task.isCancelled { pendingPhoto = nil } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                let resized = Task.detached(priority: .userInitiated) { AlbumImage.thumbnailData(data) }
                guard let jpeg = await resized.value else { throw CocoaError(.fileReadCorruptFile) }
                try Task.checkCancellation()
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appending(path: UUID().uuidString + ".jpg")
                try jpeg.write(to: url, options: .atomic)
                reload()
                selected = pictures.firstIndex(of: url) ?? 0
            } catch {
                if !Task.isCancelled { photoError = true }
            }
        }
        .sheet(isPresented: $showViewer) {
            NavigationStack {
                Group {
                    if pictures.isEmpty {
                        ContentUnavailableView("把这里的风景留下来", systemImage: "photo.on.rectangle",
                                               description: Text("点右上角添加照片，收进本机的景区相册。"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(YutoTheme.paper)
                    } else {
                        TabView(selection: $selected) {
                            ForEach(Array(pictures.enumerated()), id: \.element) { index, url in
                                AlbumPhoto(url: url, fit: true)
                                    .accessibilityLabel("第 \(index + 1) 张照片，共 \(pictures.count) 张")
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page)
                        .background(.black)
                        .safeAreaInset(edge: .bottom) {
                            if pictures.count > 1 { thumbnails }
                        }
                    }
                }
                .navigationTitle(pictures.isEmpty ? "景区相册" : "景区相册 · \(selected + 1)/\(pictures.count)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { showViewer = false } }
                    ToolbarItem(placement: .primaryAction) {
                        PhotosPicker(selection: $pendingPhoto, matching: .images) {
                            Image(systemName: "photo.badge.plus")
                        }
                        .accessibilityLabel("添加照片")
                        .disabled(photoURLs.count >= 20 || pendingPhoto != nil)
                    }
                    if pictures.indices.contains(selected), photoURLs.contains(pictures[selected]) {
                        ToolbarItem(placement: .primaryAction) {
                            Button("删除照片", systemImage: "trash", role: .destructive) {
                                pendingRemoval = pictures[selected]
                            }
                        }
                    }
                }
                .alert("照片操作未完成", isPresented: $photoError) {
                    Button("好", role: .cancel) {}
                } message: { Text("请稍后再试，或选择另一张照片。") }
                .confirmationDialog("删除这张本机照片？", isPresented: Binding(
                    get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }
                ), presenting: pendingRemoval) { url in
                    Button("删除照片", role: .destructive) { remove(url) }
                }
            }
        }
    }

    private var thumbnails: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(pictures.enumerated()), id: \.element) { index, url in
                    Button { selected = index } label: {
                        AlbumPhoto(url: url).frame(width: 58, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                if selected == index {
                                    RoundedRectangle(cornerRadius: 8).strokeBorder(.white, lineWidth: 3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("查看第 \(index + 1) 张照片")
                    .accessibilityAddTraits(index == selected ? .isSelected : [])
                }
            }.padding(.horizontal, 10).padding(.vertical, 7)
        }
        .scrollIndicators(.hidden)
        .background(.black)
    }

    private var heroCaption: String {
        switch place.featuredArtwork {
        case "WestLake": "西子湖畔，沿岸慢行"
        case "SuzhouGarden": "江南园林，移步换景"
        case "Gulangyu": "海岛街巷，听风看海"
        default: photoURLs.isEmpty ? "\(place.province)风景示意" : "\(place.city) · 我的旅行照片"
        }
    }

    private func reload() {
        photoURLs = DestinationAlbumFiles.photos(for: place.id)
    }

    private func remove(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            reload()
            selected = min(selected, max(pictures.count - 1, 0))
        } catch {
            photoError = true
        }
        pendingRemoval = nil
    }


}

private struct AlbumPhoto: View {
    let url: URL
    var fit = false

    var body: some View {
        GeometryReader { size in
            if let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable()
                    .aspectRatio(contentMode: fit ? .fit : .fill)
                    .frame(width: size.size.width, height: size.size.height)
            }
        }.clipped().accessibilityHidden(!fit)
    }
}
