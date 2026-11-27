import SwiftUI

struct DestinationReviews: View {
    @Environment(TravelStore.self) private var store
    let place: Destination
    @State private var composing = false
    @State private var rating = 5
    @State private var text = ""
    @State private var removing: DestinationReview?

    private var reviews: [DestinationReview] { store.reviews.filter { $0.destinationID == place.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                YutoSection(title: "旅行手记")
                Spacer()
                Button { composing = true } label: {
                    Label("写评价", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.buttonStyle(.plain).foregroundStyle(YutoTheme.forest)
            }
            if reviews.isEmpty {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "book.pages")
                        .font(.title2).foregroundStyle(YutoTheme.sage)
                        .frame(width: 44, height: 48)
                        .background(YutoTheme.mist, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("记下您的游览体验").font(.headline)
                        Text("哪段路好走？哪里适合歇脚？把这些发现留在本机手记里。")
                            .font(.subheadline).foregroundStyle(YutoTheme.muted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 16))
            }
            ForEach(reviews) { review in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("我的评价", systemImage: "person.crop.circle").font(.headline)
                        Spacer()
                        Button("删除评价", systemImage: "trash", role: .destructive) { removing = review }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    }
                    Label("\(review.rating) / 5", systemImage: "star.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(YutoTheme.amberInk)
                    Text(review.text)
                    Text(review.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline).foregroundStyle(YutoTheme.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(YutoTheme.porcelain, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .sheet(isPresented: $composing) {
            NavigationStack {
                Form {
                    Section("给这次旅行打分") {
                        Picker("评分", selection: $rating) {
                            ForEach(1...5, id: \.self) { value in Text("\(value) 分").tag(value) }
                        }
                    }
                    Section {
                        TextEditor(text: $text)
                            .frame(minHeight: 140)
                            .accessibilityLabel("评价内容")
                            .accessibilityIdentifier("review-text")
                    } header: {
                        Text("您的游览体验")
                    } footer: {
                        Text("\(text.count) / 500 · 保存在这台设备")
                    }
                }
                .scrollContentBackground(.hidden)
                .background(YutoTheme.paper)
                .navigationTitle("写评价")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { composing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存评价") {
                            if store.addReview(destinationID: place.id, rating: rating, text: text) {
                                text = ""
                                rating = 5
                                composing = false
                            }
                        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 500)
                    }
                }
            }
        }
        .confirmationDialog("删除这条本机评价？", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), presenting: removing) { review in
            Button("删除评价", role: .destructive) { store.deleteReview(review.id); removing = nil }
        }
    }
}
