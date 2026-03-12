import SwiftUI

struct GalleryView: View {
  @ObservedObject var store = PhotoCaptureStore.shared
  @State private var selectedPhoto: CapturedPhoto?
  @Environment(\.dismiss) var dismiss

  private let columns = [
    GridItem(.flexible(), spacing: 2),
    GridItem(.flexible(), spacing: 2),
    GridItem(.flexible(), spacing: 2)
  ]

  var body: some View {
    NavigationView {
      Group {
        if store.photos.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle")
              .font(.system(size: 48))
              .foregroundStyle(.secondary)
            Text("No captured photos yet")
              .font(AppFont.body)
              .foregroundStyle(.secondary)
            Text("Ask the AI to take a photo during a voice session")
              .font(AppFont.caption)
              .foregroundStyle(.tertiary)
              .multilineTextAlignment(.center)
          }
          .padding()
        } else {
          ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
              ForEach(store.photos) { photo in
                GalleryThumbnail(photo: photo)
                  .onTapGesture { selectedPhoto = photo }
              }
            }
          }
        }
      }
      .navigationTitle("Gallery")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") { dismiss() }
        }
      }
      .sheet(item: $selectedPhoto) { photo in
        GalleryDetailView(photo: photo)
      }
    }
  }
}

// MARK: - Thumbnail

private struct GalleryThumbnail: View {
  let photo: CapturedPhoto

  var body: some View {
    GeometryReader { geo in
      if let uiImage = UIImage(contentsOfFile: photo.fileURL.path) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
          .frame(width: geo.size.width, height: geo.size.width)
          .clipped()
      } else {
        Rectangle()
          .fill(Color(.systemGray5))
          .frame(width: geo.size.width, height: geo.size.width)
          .overlay {
            Image(systemName: "photo")
              .foregroundStyle(.secondary)
          }
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}
