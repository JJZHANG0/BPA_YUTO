import PhotosUI
import SwiftUI

struct TripAlbumView: View {
    let tripID: UUID
    @Environment(TravelStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var photos: [URL] = []
    @State private var pendingPhoto: PhotosPickerItem?
    @State private var selected: URL?
    @State private var removing: URL?
    @State private var error: String?

    var body: some View {
        YutoPage {
            if photos.isEmpty {
                ContentUnavailableView("留住这一程的风景", systemImage: "photo.on.rectangle.angled",
                                       description: Text("从手机相册添加旅行照片，点开照片即可分享给家人。"))
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                         count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.element) { index, url in
                        Button { selected = url } label: {
                            Rectangle().fill(YutoTheme.mist).aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if let image = UIImage(contentsOfFile: url.path) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(.rect)
                        }.buttonStyle(.plain).accessibilityLabel("查看第 \(index + 1) 张旅行照片")
                    }
                }
            }
            PhotosPicker(selection: $pendingPhoto, matching: .images) {
                Label(pendingPhoto == nil ? "添加旅行照片" : "正在导入照片", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(YutoButtonStyle()).disabled(pendingPhoto != nil)
            if let error { Text(error).foregroundStyle(YutoTheme.amberInk) }
        }
        .navigationTitle("行程相册").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { photos = TripAlbumFiles.items(for: tripID) }
        .task(id: pendingPhoto) {
            guard let item = pendingPhoto else { return }
            defer { if !Task.isCancelled { pendingPhoto = nil } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                let jpeg = await Task.detached(priority: .userInitiated) { AlbumImage.thumbnailData(data) }.value
                try Task.checkCancellation()
                guard store.trips.contains(where: { $0.id == tripID }), let jpeg else { throw CocoaError(.fileReadCorruptFile) }
                let folder = TripAlbumFiles.directory(for: tripID)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let file = folder.appendingPathComponent("\(Int(Date.now.timeIntervalSince1970 * 1000))-\(UUID().uuidString).jpg")
                try jpeg.write(to: file, options: .atomic)
                photos = TripAlbumFiles.items(for: tripID)
                error = nil
            } catch {
                if !Task.isCancelled { self.error = "这张照片未能保存，请重新选择。" }
            }
        }
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            NavigationStack {
                if let url = selected, let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
                        .accessibilityLabel("旅行照片")
                        .safeAreaInset(edge: .bottom) {
                            ShareLink(item: url, preview: SharePreview("旅行照片", image: Image(uiImage: image))) {
                                Label("分享给家人", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                            }.buttonStyle(YutoButtonStyle()).padding().background(YutoTheme.paper)
                        }
                        .navigationTitle("旅行照片").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("关闭") { selected = nil } }
                            ToolbarItem(placement: .primaryAction) {
                                Button("删除照片", systemImage: "trash", role: .destructive) { removing = url }
                            }
                        }
                        .confirmationDialog("从这份行程中删除照片？", isPresented: Binding(
                            get: { removing != nil }, set: { if !$0 { removing = nil } }
                        ), titleVisibility: .visible, presenting: removing) { url in
                            Button("删除照片", role: .destructive) {
                                do {
                                    try FileManager.default.removeItem(at: url)
                                    photos = TripAlbumFiles.items(for: tripID)
                                } catch { self.error = "未能删除照片，请再试一次。" }
                                selected = nil
                            }
                        }
                }
            }
        }
    }
}
