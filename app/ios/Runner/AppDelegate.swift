import Flutter
import UIKit
import AVFoundation
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var musicLibrary: PocketMusicLibrary?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PocketMusicLibrary") {
      musicLibrary = PocketMusicLibrary(messenger: registrar.messenger())
    }
  }
}

/// Import-only access: iOS music lives in this app's sandbox, never a cloud library.
final class PocketMusicLibrary: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var pendingImport: FlutterResult?
  private let worker = DispatchQueue(label: "local.eloe.pocketmusic.library")
  private var musicDirectory: URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var directory = documents.appendingPathComponent("Music", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? directory.setResourceValues(values)
    // Saved app state is also private to this device.
    var privateDocuments = documents
    try? privateDocuments.setResourceValues(values)
    return directory
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "pocket_music/library", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterError(code: "closed", message: "Library is closed.", details: nil)); return }
      switch call.method {
      case "scan":
        self.worker.async {
          let songs = self.scan()
          DispatchQueue.main.async { result(["songs": songs, "permissionDenied": false]) }
        }
      case "importFiles": self.presentPicker(result)
      case "openSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presentPicker(_ result: @escaping FlutterResult) {
    guard pendingImport == nil else { result(FlutterError(code: "busy", message: "The file picker is already open.", details: nil)); return }
    let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }.first { $0.isKeyWindow }
    guard var presenter = window?.rootViewController else {
      result(FlutterError(code: "picker", message: "Open the app before importing music.", details: nil)); return
    }
    while let presented = presenter.presentedViewController { presenter = presented }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
    picker.allowsMultipleSelection = true
    picker.delegate = self
    pendingImport = result
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingImport?([])
    pendingImport = nil
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pendingImport else { return }
    pendingImport = nil
    worker.async {
      var songs: [[String: Any]] = []
      var failures = 0
      for source in urls {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let destination = self.musicDirectory.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
        do {
          try FileManager.default.copyItem(at: source, to: destination)
          guard let song = self.metadata(destination) else {
            try? FileManager.default.removeItem(at: destination)
            failures += 1
            continue
          }
          songs.append(song)
        } catch {
          try? FileManager.default.removeItem(at: destination)
          failures += 1
        }
      }
      let completedSongs = songs
      let failureCount = failures
      DispatchQueue.main.async {
        if failureCount > 0 {
          result(FlutterError(code: "partial_import", message: "Some files could not be imported.", details: ["songs": completedSongs, "failedCount": failureCount]))
        } else { result(completedSongs) }
      }
    }
  }

  private func scan() -> [[String: Any]] {
    let urls = (try? FileManager.default.contentsOfDirectory(at: musicDirectory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? []
    return urls.compactMap { metadata($0) }.sorted { ($0["title"] as? String ?? "") < ($1["title"] as? String ?? "") }
  }

  private func metadata(_ url: URL) -> [String: Any]? {
    let asset = AVURLAsset(url: url)
    let seconds = CMTimeGetSeconds(asset.duration)
    guard seconds.isFinite, seconds > 0 else { return nil }
    let common = asset.commonMetadata
    func text(_ key: AVMetadataKey, _ fallback: String) -> String {
      let value = AVMetadataItem.metadataItems(from: common, withKey: key, keySpace: .common).first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
      return value?.isEmpty == false ? value! : fallback
    }
    let originalName = String(url.deletingPathExtension().lastPathComponent.dropFirst(37))
    var song: [String: Any] = ["id": "import:" + url.lastPathComponent, "path": url.path,
      "title": text(.commonKeyTitle, originalName), "artist": text(.commonKeyArtist, "Unknown artist"),
      "album": text(.commonKeyAlbumName, "Imported music"), "durationMs": Int(seconds * 1000)]
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let cover = caches.appendingPathComponent(url.lastPathComponent + ".jpg")
    if !FileManager.default.fileExists(atPath: cover.path),
       let image = AVMetadataItem.metadataItems(from: common, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common).first?.dataValue {
      try? image.write(to: cover, options: .atomic)
    }
    if FileManager.default.fileExists(atPath: cover.path) { song["artworkPath"] = cover.path }
    return song
  }
}
