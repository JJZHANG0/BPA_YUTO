import ImageIO
import SwiftUI

struct ProvinceMemoryView: View {
    let province: String
    let catalog: Catalog
    @Environment(TravelStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [MemoryPhoto] = []
    @State private var selectedPhoto: MemoryPhoto?
    @State private var confirmRemoval = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var completed: [Trip] {
        store.trips.filter { $0.complete && catalog.provinces(in: $0).contains(province) }
            .sorted { $0.date > $1.date }
    }

    private var journals: [DestinationReview] {
        store.reviews.filter { catalog.destination($0.destinationID)?.province == province }
    }

    var body: some View {
        NavigationStack {
            YutoPage {
                cover
                metrics
                if !completed.isEmpty {
                    YutoSection(title: "走过的行程")
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(completed) { trip in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "flag.checkered").foregroundStyle(YutoTheme.forest)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(catalog.destination(trip.destination)?.shortName ?? "已完成行程").font(.headline)
                                    Text("\(trip.displayDates) · \(trip.days)天").font(.subheadline).foregroundStyle(YutoTheme.muted)
                                }
                            }
                            if trip.id != completed.last?.id { Divider() }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).travelPanel()
                }
                if !photos.isEmpty { album }
                if !journals.isEmpty {
                    YutoSection(title: "我的旅行手记")
                    ForEach(journals) { review in
                        if let place = catalog.destination(review.destinationID) {
                            NavigationLink { DestinationDetailView(place: place, query: "") } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Label(place.shortName, systemImage: "book.pages")
                                        .font(.headline).foregroundStyle(YutoTheme.forest)
                                    Text(review.text).font(.body).lineLimit(4)
                                    Text(review.date, format: .dateTime.year().month().day())
                                        .font(.footnote).foregroundStyle(YutoTheme.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading).travelPanel()
                            }.buttonStyle(.plain)
                        }
                    }
                }

                if let marked = store.manualFootprints[province] {
                    Label("手动点亮于 " + marked.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))),
                          systemImage: "calendar.badge.checkmark")
                        .font(.subheadline).foregroundStyle(YutoTheme.muted)
                }
                if completed.isEmpty {
                    if store.manualFootprints[province] != nil {
                        Button("撤销手动点亮") { confirmRemoval = true }
                            .buttonStyle(YutoButtonStyle(primary: false))
                            .accessibilityIdentifier("footprint-unmark")
                    } else {
                        Button {
                            store.markProvince(province)
                        } label: {
                            Label("我去过，点亮\(province)", systemImage: "sun.max")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(YutoButtonStyle())
                    }
                } else {
                    Label("已完成的行程自动点亮了\(province)", systemImage: "checkmark.seal")
                        .font(.subheadline).foregroundStyle(YutoTheme.forest)
                }
            }
            .navigationTitle("旅行记忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }
            }
            .task(id: province) {
                let places = catalog.attractions.filter { $0.province == province }
                let localTrips = completed.filter { catalog.provinces(in: $0) == [province] }
                let found = await Task.detached(priority: .utility) {
                    let scenic = places.flatMap { place in
                        DestinationAlbumFiles.photos(for: place.id).map {
                            MemoryPhoto(url: $0, name: "景区相册 · " + place.shortName)
                        }
                    }
                    let tripPhotos = localTrips.flatMap { trip in
                        TripAlbumFiles.items(for: trip.id).map {
                            MemoryPhoto(url: $0, name: "行程相册 · " + trip.displayDates)
                        }
                    }
                    return MemoryPhoto.unique(scenic + tripPhotos)
                }.value
                if !Task.isCancelled { photos = found }
            }
            .confirmationDialog("撤销\(province)的手动点亮？", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("撤销点亮", role: .destructive) { store.removeManualFootprint(province) }
                Button("取消", role: .cancel) {}
            }
            .sheet(item: $selectedPhoto) { photo in
                NavigationStack {
                    MemoryPhotoImage(url: photo.url, maximumPixelSize: 1400, mode: .fit)
                        .background(.black)
                        .navigationTitle(photo.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("关闭") { selectedPhoto = nil } }
                            ToolbarItem(placement: .primaryAction) { ShareLink(item: photo.url) }
                        }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var cover: some View {
        let image = ProvinceIllustration.photo(for: province)
        let lit = store.visitedProvinces(in: catalog).contains(province)
        return VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 52)
            Text(province).font(.system(.largeTitle, design: .serif, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Label(lit ? "已点亮" : "未点亮", systemImage: lit ? "sun.max.fill" : "circle.dashed")
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .bottomLeading)
        .background {
            YutoPhoto(name: image.name, subdirectory: image.folder)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: YutoTheme.round))
    }

    private var metrics: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                                                  : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            metric("完成行程", value: completed.count, unit: "次", icon: "map")
            metric("旅行照片", value: photos.count, unit: "张", icon: "photo")
            metric("旅行手记", value: journals.count, unit: "篇", icon: "book")
        }.travelPanel()
    }

    private func metric(_ title: String, value: Int, unit: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.footnote.weight(.medium)).foregroundStyle(YutoTheme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)").font(.title2.bold().monospacedDigit())
                Text(unit).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var album: some View {
        VStack(alignment: .leading, spacing: 12) {
            YutoSection(title: "我的旅行照片")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                ForEach(photos) { photo in
                    Button { selectedPhoto = photo } label: {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                            .overlay { MemoryPhotoImage(url: photo.url, maximumPixelSize: 300) }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .contentShape(.rect)
                    }.buttonStyle(.plain).accessibilityLabel("查看\(photo.name)的照片")
                }
            }
        }
    }
}

private struct MemoryPhoto: Identifiable {
    let url: URL
    let name: String
    var id: URL { url }

    // A photo imported into two albums may have different filenames but identical JPEG data.
    static func unique(_ photos: [Self]) -> [Self] {
        var sizes: [Int: [URL]] = [:]
        return photos.filter { photo in
            guard let size = try? photo.url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return true }
            let matches = sizes[size, default: []]
            guard !matches.contains(where: { FileManager.default.contentsEqual(atPath: $0.path, andPath: photo.url.path) }) else {
                return false
            }
            sizes[size, default: []].append(photo.url)
            return true
        }
    }
}

private struct MemoryPhotoImage: View {
    let url: URL
    let maximumPixelSize: Int
    var mode: ContentMode = .fill
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { size in
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
                    .frame(width: size.size.width, height: size.size.height)
            } else {
                YutoTheme.mist
            }
        }
        .clipped()
        .task(id: url) {
            let url = url
            let size = maximumPixelSize
            let thumbnail = await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: size
                      ] as CFDictionary) else { return nil as UIImage? }
                return UIImage(cgImage: thumbnail)
            }.value
            if !Task.isCancelled { image = thumbnail }
        }
        .accessibilityHidden(true)
    }
}
