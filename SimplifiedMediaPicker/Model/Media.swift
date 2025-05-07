//
//  Created by Alex.M on 31.05.2022.
//

import Foundation
import AVFoundation
import UIKit

// Media type enum
public enum MediaType {
    case image
    case video
    case document
}

// Core media model protocol
public protocol MediaModelProtocol {
    var mediaType: MediaType { get }
    var duration: TimeInterval? { get }
    
    func getURL() async -> URL?
    func getData() async -> Data?
}

// Media model that wraps a MediaModelProtocol
public struct Media: Identifiable {
    public var id = UUID()
    internal let source: MediaModelProtocol
    
    public init(source: MediaModelProtocol) {
        self.source = source
    }
    
    public var type: MediaType { source.mediaType }
    public var duration: TimeInterval? { source.duration }
    
    public func getURL() async -> URL? { await source.getURL() }
    public func getData() async -> Data? { await source.getData() }
}

// URL-based media model
public class URLMediaModel: MediaModelProtocol, Identifiable {
    public var id = UUID().uuidString
    private let url: URL
    public let mediaType: MediaType
    public var duration: TimeInterval?
    
    public init(url: URL, type: MediaType? = nil) {
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
                let duration = try? await asset.load(.duration)
                self.duration = duration.map { CMTimeGetSeconds($0) }
            }
        }
    }
    
    public func getURL() async -> URL? { return url }
    
    public func getData() async -> Data? {
        try? Data(contentsOf: url)
    }
}

// Media with caption
public struct MediaWithCaption: Identifiable {
    public var id = UUID().uuidString
    public var media: Media
    public var caption: String = ""
    
    public init(media: Media, caption: String = "") {
        self.id = id
        self.media = media
        self.caption = caption
    }
}
