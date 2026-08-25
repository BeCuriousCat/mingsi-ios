import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

enum PhotoMemoryPermissionStatus: Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted

    var permitsPhotoSelection: Bool {
        self == .authorized || self == .limited
    }
}

/// Keeps photo-library access explicit and local. The app persists only
/// `PHAsset.localIdentifier` values in its database.
final class PhotoMemoryMediaService {
    static let sharedAlbumTitle = "明思·奇遇"

    func hasFullPhotoLibraryReadAuthorization() -> Bool {
        PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
    }

    func photoLibraryAddOnlyPermissionStatus() -> PhotoMemoryPermissionStatus {
        Self.photoLibraryPermissionStatus(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }

    func cameraPermissionStatus() -> PhotoMemoryPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    func requestPhotoLibraryAddOnlyPermission() async -> PhotoMemoryPermissionStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return Self.photoLibraryPermissionStatus(current) }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return Self.photoLibraryPermissionStatus(status)
    }

    func requestCameraPermission() async -> PhotoMemoryPermissionStatus {
        let current = AVCaptureDevice.authorizationStatus(for: .video)
        guard current == .notDetermined else { return cameraPermissionStatus() }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted ? .authorized : cameraPermissionStatus()
    }

    func thumbnail(for assetLocalIdentifier: String, targetSize: CGSize) async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            var didResume = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !didResume else { return }
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                didResume = true
                let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
                let failed = (info?[PHImageErrorKey] as? Error) != nil
                continuation.resume(returning: cancelled || failed ? nil : image)
            }
        }
    }

    /// Saves the capture directly into the shared album and returns its local
    /// identifier. This avoids needing read access merely to look the new asset
    /// up again before adding it to the album.
    func saveCapturedImage(_ image: UIImage) async throws -> String {
        guard (await requestPhotoLibraryAddOnlyPermission()).permitsPhotoSelection else {
            throw PhotoMemoryMediaError.photoLibraryAddPermissionRequired
        }
        var placeholderIdentifier: String?
        try await performPhotoLibraryChanges {
            let request = PHAssetCreationRequest.creationRequestForAsset(from: image)
            guard let placeholder = request.placeholderForCreatedAsset else { return }
            placeholderIdentifier = placeholder.localIdentifier
            let album: PHAssetCollectionChangeRequest?
            if let existing = Self.sharedAlbum() {
                album = PHAssetCollectionChangeRequest(for: existing)
            } else {
                album = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                    withTitle: Self.sharedAlbumTitle
                )
            }
            album?.addAssets([placeholder] as NSArray)
        }
        guard let placeholderIdentifier else { throw PhotoMemoryMediaError.captureSaveFailed }
        return placeholderIdentifier
    }

    /// Adds a picked existing asset to the shared album without copying its bytes.
    func addSelectedAssetToSharedAlbum(assetLocalIdentifier: String) async throws {
        guard photoLibraryAddOnlyPermissionStatus().permitsPhotoSelection else {
            throw PhotoMemoryMediaError.photoLibraryAddPermissionRequired
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil)
        guard let asset = assets.firstObject else {
            throw PhotoMemoryMediaError.selectedAssetUnavailable
        }
        try await performPhotoLibraryChanges {
            let album: PHAssetCollectionChangeRequest?
            if let existing = Self.sharedAlbum() {
                album = PHAssetCollectionChangeRequest(for: existing)
            } else {
                album = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: Self.sharedAlbumTitle)
            }
            album?.addAssets([asset] as NSArray)
        }
    }

    private func performPhotoLibraryChanges(_ changes: @escaping () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoMemoryMediaError.captureSaveFailed)
                }
            }
        }
    }

    private static func sharedAlbum() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title == %@", sharedAlbumTitle)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options).firstObject
    }

    private static func photoLibraryPermissionStatus(_ status: PHAuthorizationStatus) -> PhotoMemoryPermissionStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}

enum PhotoMemoryMediaError: LocalizedError {
    case photoLibraryAddPermissionRequired
    case selectedAssetUnavailable
    case captureSaveFailed

    var errorDescription: String? {
        switch self {
        case .photoLibraryAddPermissionRequired: return "需要允许添加照片，才能把这张照片留到“明思·奇遇”相册。"
        case .selectedAssetUnavailable: return "无法读取刚才选择的照片，因此没有附上。"
        case .captureSaveFailed: return "照片没有保存成功。"
        }
    }
}

struct PhotoMemoryLibraryPicker: UIViewControllerRepresentable {
    var onSelect: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        return PHPickerViewController(configuration: configuration)
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect, onCancel: onCancel) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (String) -> Void
        let onCancel: () -> Void

        init(onSelect: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let identifier = results.first?.assetIdentifier else {
                onCancel()
                return
            }
            onSelect(identifier)
        }
    }
}

struct PhotoMemoryCameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                onCancel()
                return
            }
            onCapture(image)
        }
    }
}
