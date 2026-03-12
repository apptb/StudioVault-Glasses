import SwiftUI

struct GalleryDetailView: View {
  let photo: CapturedPhoto
  @ObservedObject var store = PhotoCaptureStore.shared
  @Environment(\.dismiss) var dismiss
  @State private var showDeleteConfirmation = false
  @State private var showShareSheet = false

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        if let uiImage = UIImage(contentsOfFile: photo.fileURL.path) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text(photo.timestamp, style: .date)
            .font(AppFont.subheadline)
            .foregroundStyle(.secondary)
          + Text(" ")
          + Text(photo.timestamp, style: .time)
            .font(AppFont.subheadline)
            .foregroundStyle(.secondary)

          if let description = photo.description, !description.isEmpty {
            Text(description)
              .font(AppFont.body)
          }

          HStack(spacing: 16) {
            Button {
              showShareSheet = true
            } label: {
              Label("Share", systemImage: "square.and.arrow.up")
                .font(AppFont.body)
            }

            Spacer()

            Button(role: .destructive) {
              showDeleteConfirmation = true
            } label: {
              Label("Delete", systemImage: "trash")
                .font(AppFont.body)
            }
          }
          .padding(.top, 8)
        }
        .padding()
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") { dismiss() }
        }
      }
      .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirmation) {
        Button("Delete", role: .destructive) {
          store.deletePhoto(photo)
          dismiss()
        }
      }
      .sheet(isPresented: $showShareSheet) {
        if let uiImage = UIImage(contentsOfFile: photo.fileURL.path) {
          ShareSheet(photo: uiImage)
        }
      }
    }
  }
}
