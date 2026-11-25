import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct DestinationGallery: View {
    let place: Destination
    @State private var photoURLs: [URL] = []
    @State private var pendingPhoto: PhotosPickerItem?
    @State private var selected: Int?
    @State private var showViewer = false
    @State private var photoError = false
    @State private var pendingRemoval: URL?

    private var bundledPhoto: URL? {
        guard let name = place.featuredArtwork else { return nil }
        return Bundle.main.url(forResource: name, withExtension: "jpg")
    }

    private var pictures: [URL] { [bundledPhoto].compactMap { $0 } + photoURLs }

    private var folder: URL {
        URL.applicationSupportDirectory.appending(path: "DestinationAlbums", directoryHint: .isDirectory)
            .appending(path: place.id, directoryHint: .isDirectory)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            galleryCover
            HStack(alignment: .center, spacing: 8) {
                YutoSection(title: "景区相册", detail: pictures.isEmpty ? "封面为地区示意" : "\(pictures.count) 张照片")
                Spacer(minLength: 4)
                PhotosPicker(selection: $pendingPhoto, matching: .images) {
                    Label("添加照片", systemImage: "plus").frame(minHeight: 44)
                }
                .font(.subheadline.weight(.semibold))
                .disabled(photoURLs.count >= 20)
            }
            if pictures.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        ForEach(Array(pictures.enumerated()), id: \.element) { index, url in
                            Button { open(index) } label: {
                                AlbumPhoto(url: url).frame(width: 65, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain)
                            .accessibilityLabel("查看第 \(index + 1) 张照片")
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
        .task { reload() }
        .task(id: pendingPhoto) {
            guard let item = pendingPhoto else { return }
            defer { if !Task.isCancelled { pendingPhoto = nil } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                let resized = Task.detached(priority: .userInitiated) { Self.thumbnailData(data) }
                guard let jpeg = await resized.value else { throw CocoaError(.fileReadCorruptFile) }
                try Task.checkCancellation()
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appending(path: UUID().uuidString + ".jpg")
                try jpeg.write(to: url, options: .atomic)
                reload()
            } catch {
                if !Task.isCancelled { photoError = true }
            }
        }
        .alert("没有保存这张照片", isPresented: $photoError) {
            Button("好", role: .cancel) {}
        } message: { Text("请试试选择另一张照片。") }
        .sheet(isPresented: $showViewer) {
            NavigationStack {
                TabView(selection: $selected) {
                    ForEach(Array(pictures.enumerated()), id: \.element) { index, url in
                        AlbumPhoto(url: url, fit: true)
                            .accessibilityLabel("第 \(index + 1) 张照片，共 \(pictures.count) 张")
                            .tag(Optional(index))
                    }
                }
                .tabViewStyle(.page)
                .background(.black)
                .navigationTitle("景区相册")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("关闭") { showViewer = false } }
                    if let selected, pictures.indices.contains(selected), photoURLs.contains(pictures[selected]) {
                        ToolbarItem(placement: .primaryAction) {
                            Button("删除照片", systemImage: "trash", role: .destructive) {
                                pendingRemoval = pictures[selected]
                            }
                        }
                    }
                }
                .confirmationDialog("删除这张本机照片？", isPresented: Binding(
                    get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }
                ), presenting: pendingRemoval) { url in
                    Button("删除照片", role: .destructive) { remove(url) }
                }
            }
        }
    }

    @ViewBuilder
    private var galleryCover: some View {
        if let first = pictures.first {
            Button { open(0) } label: {
                AlbumPhoto(url: first).frame(height: 236)
                    .overlay(alignment: .bottomTrailing) {
                        Label("相册", systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold)).padding(10)
                            .background(.regularMaterial, in: Capsule())
                            .padding(12)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain).accessibilityLabel("打开景区相册")
        } else {
            let cover = ProvinceIllustration.photo(for: place.province)
            YutoPhoto(name: cover.name, subdirectory: cover.folder)
                .frame(height: 190)
                .overlay(alignment: .bottomTrailing) {
                    Text("地区示意").font(.subheadline.weight(.semibold)).padding(10)
                        .background(.regularMaterial, in: Capsule()).padding(12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }

    private func open(_ index: Int) {
        selected = index
        showViewer = true
    }

    private func reload() {
        photoURLs = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func remove(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            showViewer = false
            reload()
        } catch {
            showViewer = false
            photoError = true
        }
        pendingRemoval = nil
    }

    nonisolated private static func thumbnailData(_ input: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(input as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1400
              ] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
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
