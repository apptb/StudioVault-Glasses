import Foundation
import UIKit

@MainActor
class PhotoCaptureStore: ObservableObject {
  static let shared = PhotoCaptureStore()

  @Published var photos: [CapturedPhoto] = []

  private let capturesDir = CapturedPhoto.capturesDirectory
  private let manifestFile: URL

  private init() {
    manifestFile = capturesDir.appendingPathComponent("manifest.json")
    ensureDirectoryExists()
    loadManifest()
  }

  /// Save a UIImage as JPEG, add to manifest, return the CapturedPhoto
  func saveFrame(_ image: UIImage, description: String? = nil) -> CapturedPhoto? {
    guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = Date()
    let filename = "capture_\(formatter.string(from: timestamp)).jpg"
    let fileURL = capturesDir.appendingPathComponent(filename)

    do {
      try jpegData.write(to: fileURL)
    } catch {
      NSLog("[PhotoCapture] Failed to write: %@", error.localizedDescription)
      return nil
    }

    let photo = CapturedPhoto(
      id: UUID().uuidString,
      filename: filename,
      timestamp: timestamp,
      description: description
    )
    photos.insert(photo, at: 0)
    saveManifest()
    NSLog("[PhotoCapture] Saved: %@", filename)
    return photo
  }

  func deletePhoto(_ photo: CapturedPhoto) {
    try? FileManager.default.removeItem(at: photo.fileURL)
    photos.removeAll { $0.id == photo.id }
    saveManifest()
  }

  // MARK: - Private

  private func ensureDirectoryExists() {
    if !FileManager.default.fileExists(atPath: capturesDir.path) {
      try? FileManager.default.createDirectory(at: capturesDir, withIntermediateDirectories: true)
    }
  }

  private func loadManifest() {
    guard FileManager.default.fileExists(atPath: manifestFile.path),
          let data = try? Data(contentsOf: manifestFile) else { return }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let loaded = try? decoder.decode([CapturedPhoto].self, from: data) {
      // Filter out entries whose files no longer exist
      photos = loaded.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }
  }

  private func saveManifest() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted
    guard let data = try? encoder.encode(photos) else { return }
    try? data.write(to: manifestFile)
  }
}
