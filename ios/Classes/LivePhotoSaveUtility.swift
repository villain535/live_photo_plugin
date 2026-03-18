import Foundation
import AVFoundation
import Photos
import CoreImage

final class LivePhotoSaveUtility {
    
    typealias Completion = (Result<Void, Error>) -> Void
    
    enum LivePhotoSaveError: LocalizedError {
        case photoLibraryPermissionDenied
        case inputVideoMissing
        case inputVideoDataIsEmpty
        case metadataResourceMissing
        case failedToCreateComposition
        case failedToCreateExportSession
        case failedToExportPreparedClip
        case failedToWriteTemporaryVideo
        case conversionFailed(String)
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .photoLibraryPermissionDenied:
                return "Photo Library access denied."
            case .inputVideoMissing:
                return "Input video file is missing."
            case .inputVideoDataIsEmpty:
                return "Input video data is empty."
            case .metadataResourceMissing:
                return "metadata.mov is missing in the app bundle."
            case .failedToCreateComposition:
                return "Failed to create video composition."
            case .failedToCreateExportSession:
                return "Failed to create export session."
            case .failedToExportPreparedClip:
                return "Failed to export prepared clip."
            case .failedToWriteTemporaryVideo:
                return "Failed to write temporary video."
            case .conversionFailed(let message):
                return message
            case .unknown:
                return "Unknown error."
            }
        }
    }
    
    static let shared = LivePhotoSaveUtility()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    func saveAsLivePhoto(videoURL: URL, completion: @escaping Completion) {
        requestPhotoLibraryAccessIfNeeded { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                
            case .success:
                guard self.fileManager.fileExists(atPath: videoURL.path) else {
                    DispatchQueue.main.async {
                        completion(.failure(LivePhotoSaveError.inputVideoMissing))
                    }
                    return
                }
                
                guard let pluginBundle = Bundle(for: LivePhotoPlugin.self) as Bundle?,
                      pluginBundle.url(forResource: "metadata", withExtension: "mov") != nil else {
                    DispatchQueue.main.async {
                        completion(.failure(LivePhotoSaveError.metadataResourceMissing))
                    }
                    return
                }
                
                self.prepare60FPSClip(from: videoURL) { [weak self] prepareResult in
                    guard let self else { return }
                    
                    switch prepareResult {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                        
                    case .success(let preparedURL):
                        LivePhotoUtil.convertVideo(preparedURL.path) { success, message in
                            self.removeFileIfNeeded(at: preparedURL)
                            
                            DispatchQueue.main.async {
                                if success {
                                    completion(.success(()))
                                } else {
                                    completion(.failure(
                                        LivePhotoSaveError.conversionFailed(
                                            message ?? "Live Photo conversion failed."
                                        )
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func saveAsLivePhoto(videoData: Data, completion: @escaping Completion) {
        guard !videoData.isEmpty else {
            DispatchQueue.main.async {
                completion(.failure(LivePhotoSaveError.inputVideoDataIsEmpty))
            }
            return
        }
        
        do {
            let inputURL = try makeTemporaryVideoURL(prefix: "input", fileExtension: "mp4")
            try videoData.write(to: inputURL, options: .atomic)
            
            saveAsLivePhoto(videoURL: inputURL) { [weak self] result in
                self?.removeFileIfNeeded(at: inputURL)
                completion(result)
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(LivePhotoSaveError.failedToWriteTemporaryVideo))
            }
        }
    }
}

// MARK: - Preparation

private extension LivePhotoSaveUtility {
    
    func prepare60FPSClip(
        from inputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let asset = AVURLAsset(url: inputURL)
        
        Task {
            do {
                let duration = try await asset.load(.duration)
                let totalSeconds = CMTimeGetSeconds(duration)
                
                guard totalSeconds > 0 else {
                    DispatchQueue.main.async {
                        completion(.failure(LivePhotoSaveError.failedToExportPreparedClip))
                    }
                    return
                }
                
                // Target exactly 1.0 second for wallpaper preparation
                let targetSeconds = min(2.0, totalSeconds)
                let startSeconds = 0.0
//                max(0, (totalSeconds - targetSeconds) / 2.0)
                
                let timeRange = CMTimeRange(
                    start: CMTime(seconds: startSeconds, preferredTimescale: 600),
                    duration: CMTime(seconds: targetSeconds, preferredTimescale: 600)
                )
                
                guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                    DispatchQueue.main.async {
                        completion(.failure(LivePhotoSaveError.failedToCreateComposition))
                    }
                    return
                }
                
                let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first
                
                let composition = AVMutableComposition()
                
                guard let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    DispatchQueue.main.async {
                        completion(.failure(LivePhotoSaveError.failedToCreateComposition))
                    }
                    return
                }
                
                try compositionVideoTrack.insertTimeRange(
                    timeRange,
                    of: sourceVideoTrack,
                    at: .zero
                )
                
                if let sourceAudioTrack,
                   let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                   ) {
                    try compositionAudioTrack.insertTimeRange(
                        timeRange,
                        of: sourceAudioTrack,
                        at: .zero
                    )
                }
                
//                let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
//                let naturalSize = try await sourceVideoTrack.load(.naturalSize)
//                
//                let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
//                let sourceSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
//                let targetSize = CGSize(width: 1080, height: 1920)
//                
//                let scale = max(
//                    targetSize.width / sourceSize.width,
//                    targetSize.height / sourceSize.height
//                )
//                
//                let scaledSize = CGSize(
//                    width: sourceSize.width * scale,
//                    height: sourceSize.height * scale
//                )
//                
//                let tx = (targetSize.width - scaledSize.width) / 2.0
//                let ty = (targetSize.height - scaledSize.height) / 2.0
//                
//                let instruction = AVMutableVideoCompositionInstruction()
//                instruction.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: targetSeconds, preferredTimescale: 600))
//                
//                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
//                
//                let finalTransform = preferredTransform
//                    .concatenating(CGAffineTransform(scaleX: scale, y: scale))
//                    .concatenating(CGAffineTransform(translationX: tx, y: ty))
//                
//                layerInstruction.setTransform(finalTransform, at: .zero)
//                instruction.layerInstructions = [layerInstruction]
//                
//                let videoComposition = AVMutableVideoComposition()
//                videoComposition.instructions = [instruction]
//                videoComposition.renderSize = targetSize
//                videoComposition.frameDuration = CMTime(value: 1, timescale: 60) // 60 FPS
                let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
                let naturalSize = try await sourceVideoTrack.load(.naturalSize)

                let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
                let sourceSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
                let targetSize = CGSize(width: 1080, height: 1920)

                let videoComposition: AVMutableVideoComposition

                if sourceSize.width > sourceSize.height {
                    videoComposition = makeBlurredPortraitComposition(
                        for: composition,
                        sourceTrack: compositionVideoTrack,
                        preferredTransform: preferredTransform,
                        naturalSize: naturalSize,
                        renderSize: targetSize,
                        frameDuration: CMTime(value: 1, timescale: 60)
                    )
                } else {
                    videoComposition = makeFillComposition(
                        for: compositionVideoTrack,
                        preferredTransform: preferredTransform,
                        naturalSize: naturalSize,
                        renderSize: targetSize,
                        duration: CMTime(seconds: targetSeconds, preferredTimescale: 600),
                        frameDuration: CMTime(value: 1, timescale: 60)
                    )
                }
                
                let outputURL = try self.makeTemporaryVideoURL(prefix: "prepared60fps", fileExtension: "mov")
                self.removeFileIfNeeded(at: outputURL)
                
                guard let exportSession = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetHighestQuality
                ) else {
                    DispatchQueue.main.async {
                        completion(.failure(LivePhotoSaveError.failedToCreateExportSession))
                    }
                    return
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mov
                exportSession.videoComposition = videoComposition
                exportSession.shouldOptimizeForNetworkUse = false
                
                exportSession.exportAsynchronously {
                    DispatchQueue.main.async {
                        switch exportSession.status {
                        case .completed:
                            completion(.success(outputURL))
                        case .failed:
                            completion(.failure(exportSession.error ?? LivePhotoSaveError.failedToExportPreparedClip))
                        case .cancelled:
                            completion(.failure(LivePhotoSaveError.failedToExportPreparedClip))
                        default:
                            completion(.failure(exportSession.error ?? LivePhotoSaveError.unknown))
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Permissions

private extension LivePhotoSaveUtility {
    
    func requestPhotoLibraryAccessIfNeeded(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            
            switch status {
            case .authorized, .limited:
                completion(.success(()))
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    if newStatus == .authorized || newStatus == .limited {
                        completion(.success(()))
                    } else {
                        completion(.failure(LivePhotoSaveError.photoLibraryPermissionDenied))
                    }
                }
            default:
                completion(.failure(LivePhotoSaveError.photoLibraryPermissionDenied))
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            
            switch status {
            case .authorized:
                completion(.success(()))
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    if newStatus == .authorized {
                        completion(.success(()))
                    } else {
                        completion(.failure(LivePhotoSaveError.photoLibraryPermissionDenied))
                    }
                }
            default:
                completion(.failure(LivePhotoSaveError.photoLibraryPermissionDenied))
            }
        }
    }
}

// MARK: - Helpers

private extension LivePhotoSaveUtility {
    
    func makeTemporaryVideoURL(prefix: String, fileExtension: String) throws -> URL {
        let directory = fileManager.temporaryDirectory.appendingPathComponent("live_photo_prepare", isDirectory: true)
        
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        return directory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }
    
    func removeFileIfNeeded(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }
}


private extension LivePhotoSaveUtility {
    
    func makeFillComposition(
        for track: AVCompositionTrack,
        preferredTransform: CGAffineTransform,
        naturalSize: CGSize,
        renderSize: CGSize,
        duration: CMTime,
        frameDuration: CMTime
    ) -> AVMutableVideoComposition {
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let sourceSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
        
        let scale = max(
            renderSize.width / sourceSize.width,
            renderSize.height / sourceSize.height
        )
        
        let scaledSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        
        let tx = (renderSize.width - scaledSize.width) / 2.0
        let ty = (renderSize.height - scaledSize.height) / 2.0
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        
        let finalTransform = normalizeTransform(
            preferredTransform,
            naturalSize: naturalSize
        )
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        .concatenating(CGAffineTransform(translationX: tx, y: ty))
        
        layerInstruction.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [layerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = frameDuration
        
        return videoComposition
    }
    
    func makeBlurredPortraitComposition(
        for composition: AVAsset,
        sourceTrack: AVCompositionTrack,
        preferredTransform: CGAffineTransform,
        naturalSize: CGSize,
        renderSize: CGSize,
        frameDuration: CMTime
    ) -> AVMutableVideoComposition {
        let normalizedTransform = normalizeTransform(
            preferredTransform,
            naturalSize: naturalSize
        )
        
        let transformedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let sourceSize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
        
        let fillScale = max(
            renderSize.width / sourceSize.width,
            renderSize.height / sourceSize.height
        )
        
        let fitScale = min(
            renderSize.width / sourceSize.width,
            renderSize.height / sourceSize.height
        )
        
        let blurRadius: Double = 35.0
        
        let videoComposition = AVMutableVideoComposition(
            asset: composition,
            applyingCIFiltersWithHandler: { request in
                let outputRect = CGRect(origin: .zero, size: renderSize)
                
                let sourceImage = request.sourceImage
                    .transformed(by: normalizedTransform)
                
                let filledSize = CGSize(
                    width: sourceSize.width * fillScale,
                    height: sourceSize.height * fillScale
                )
                
                let fillTransform = CGAffineTransform(
                    translationX: (renderSize.width - filledSize.width) / 2.0,
                    y: (renderSize.height - filledSize.height) / 2.0
                ).scaledBy(x: fillScale, y: fillScale)
                
                let background = sourceImage
                    .transformed(by: fillTransform)
                    .clampedToExtent()
                    .applyingFilter(
                        "CIGaussianBlur",
                        parameters: [kCIInputRadiusKey: blurRadius]
                    )
                    .cropped(to: outputRect)
                
                let fittedSize = CGSize(
                    width: sourceSize.width * fitScale,
                    height: sourceSize.height * fitScale
                )
                
                let fitTransform = CGAffineTransform(
                    translationX: (renderSize.width - fittedSize.width) / 2.0,
                    y: (renderSize.height - fittedSize.height) / 2.0
                ).scaledBy(x: fitScale, y: fitScale)
                
                let foreground = sourceImage
                    .transformed(by: fitTransform)
                
                let result = foreground.composited(over: background)
                request.finish(with: result, context: nil)
            }
        )
        
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = frameDuration
        
        return videoComposition
    }
    
    func normalizeTransform(
        _ preferredTransform: CGAffineTransform,
        naturalSize: CGSize
    ) -> CGAffineTransform {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return preferredTransform.translatedBy(x: -rect.origin.x, y: -rect.origin.y)
    }
}
