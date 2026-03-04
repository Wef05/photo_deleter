import Photos
import SwiftUI

@MainActor
final class PhotoCleanerViewModel: ObservableObject {
    @Published var currentImage: UIImage?
    @Published var showAccessAlert = false

    private(set) var finished = false
    private var assets: [PHAsset] = []
    private var index = 0
    private var actions: [Action] = []

    struct Action {
        let index: Int
        let type: Decision
    }

    enum Decision {
        case delete
        case skip
    }

    var canUndo: Bool { !actions.isEmpty }

    var progressText: String {
        guard !assets.isEmpty else { return "暂无可处理照片" }
        return "\(min(index + 1, assets.count))/\(assets.count)"
    }

    func requestAccessAndLoad() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            showAccessAlert = true
            return
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetched = PHAsset.fetchAssets(with: .image, options: options)
        assets = (0..<fetched.count).map { fetched.object(at: $0) }
        finished = assets.isEmpty
        await loadCurrentImage()
    }

    func markDelete() {
        apply(.delete)
    }

    func skip() {
        apply(.skip)
    }

    func undo() {
        guard let last = actions.popLast() else { return }
        index = last.index
        finished = false
        Task { await loadCurrentImage() }
    }

    private func apply(_ decision: Decision) {
        guard index < assets.count else { return }
        actions.append(Action(index: index, type: decision))
        index += 1
        finished = index >= assets.count
        Task { await loadCurrentImage() }
    }

    private func loadCurrentImage() async {
        guard index < assets.count else {
            currentImage = nil
            return
        }

        let target = assets[index]
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast

        await withCheckedContinuation { continuation in
            manager.requestImage(for: target,
                                 targetSize: CGSize(width: 1200, height: 1200),
                                 contentMode: .aspectFill,
                                 options: options) { [weak self] image, _ in
                self?.currentImage = image
                continuation.resume()
            }
        }
    }
}
