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
    private var pendingDeletionAssets: [PHAsset] = []
    private let imageLoadLock = NSLock()

    struct Action {
        let index: Int
        let type: Decision
        let assetIdentifier: String?
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

    func markForDeletion() {
        apply(.delete)
    }

    func skip() {
        apply(.skip)
    }

    func undo() {
        guard let last = actions.popLast() else { return }
        switch last.type {
        case .delete:
            if let assetIdentifier = last.assetIdentifier,
               let pendingIndex = pendingDeletionAssets.firstIndex(where: { $0.localIdentifier == assetIdentifier }) {
                pendingDeletionAssets.remove(at: pendingIndex)
            }
        case .skip:
            break
        }
        index = last.index
        finished = false
        Task { await loadCurrentImage() }
    }

    private func apply(_ decision: Decision) {
        guard index < assets.count else { return }
        switch decision {
        case .delete:
            pendingDeletionAssets.append(assets[index])
            actions.append(Action(index: index, type: decision, assetIdentifier: assets[index].localIdentifier))
        case .skip:
            actions.append(Action(index: index, type: decision, assetIdentifier: nil))
        }
        index += 1
        finished = index >= assets.count
        Task {
            await loadCurrentImage()
            if finished {
                await deleteMarkedAssets()
            }
        }
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
            var didResume = false
            var timeoutTask: Task<Void, Never>?
            let resume: () -> Void = {
                self.imageLoadLock.lock()
                defer { self.imageLoadLock.unlock() }
                guard !didResume else { return }
                didResume = true
                timeoutTask?.cancel()
                continuation.resume()
            }

            timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                resume()
            }

            manager.requestImage(for: target,
                                 targetSize: CGSize(width: 1200, height: 1200),
                                 contentMode: .aspectFill,
                                 options: options) { [weak self] image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if degraded { return }

                Task { @MainActor in
                    self?.currentImage = image
                }
                resume()
            }
        }
    }

    private func deleteMarkedAssets() async {
        guard !pendingDeletionAssets.isEmpty else { return }
        let toDelete = pendingDeletionAssets
        pendingDeletionAssets.removeAll()

        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(toDelete as NSArray)
            }) { _, _ in
                continuation.resume()
            }
        }
    }
}
