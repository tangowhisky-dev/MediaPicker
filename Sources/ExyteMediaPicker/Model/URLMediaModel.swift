import Foundation
import AVFoundation
import UIKit

public class URLMediaModel: MediaModelProtocol, Identifiable, Equatable {
    public var id: String
    private let url: URL
    public let mediaType: MediaType
    public var duration: CGFloat?
    
    public init(url: URL, type: MediaType? = nil) {
        self.id = UUID().uuidString
        self.url = url
        
        // Determine media type if not provided
        if let type = type {
            self.mediaType = type
        } else {
            let fileExtension = url.pathExtension.lowercased()
            if ["jpg", "jpeg", "png", "heic", "heif"].contains(fileExtension) {
                self.mediaType = .image
            } else if ["mov", "mp4", "m4v"].contains(fileExtension) {
                self.mediaType = .video
            } else {
                self.mediaType = .document
            }
        }
        
        // Calculate duration for videos
        if self.mediaType == .video {
            let asset = AVAsset(url: url)
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    self.duration = CGFloat(CMTimeGetSeconds(duration))
                } catch {
                    print("Error loading duration: \(error)")
                }
            }
        }
    }
    
    public func getURL() async -> URL? {
        return url
    }
    
    public func getThumbnailURL() async -> URL? {
        if mediaType == .image {
            return url
        } else if mediaType == .video {
            if let thumbnailData = await generateVideoThumbnail() {
                return FileManager.storeToTempDir(data: thumbnailData)
            }
        }
        return nil
    }
    
    public func getData() async throws -> Data? {
        return try Data(contentsOf: url)
    }
    
    public func getThumbnailData() async -> Data? {
        if mediaType == .image {
            return try? Data(contentsOf: url)
        } else if mediaType == .video {
            return await generateVideoThumbnail()
        }
        return nil
    }
    
    private func generateVideoThumbnail() async -> Data? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
    
    public static func == (lhs: URLMediaModel, rhs: URLMediaModel) -> Bool {
        return lhs.id == rhs.id
    }
}

