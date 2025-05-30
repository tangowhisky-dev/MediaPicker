//
//  FileManager.swift
//  
//
//  Created by Alisa Mylnikova on 12.07.2022.
//

import SwiftUI
import AVFoundation

extension FileManager {

    static var tempPath: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    static var imageFileExtension: String { ".jpg" }
    static var videoFileExtension: String { ".mp4" }

//    static func storeToTempDir(url: URL) -> URL {
//        let id = UUID().uuidString
//        let path = FileManager.tempPath.appendingPathComponent(id + Self.imageFileExtension)
//
//        try? FileManager.default.copyItem(at: url, to: path)
//        return path
//    }
//
//    static func storeToTempDir(data: Data) -> URL {
//        let id = UUID().uuidString
//        let path = FileManager.tempPath.appendingPathComponent(id + Self.imageFileExtension)
//
//        try? data.write(to: path)
//        return path
//    }

    static func getTempUrl() -> URL {
        let id = UUID().uuidString
        return FileManager.tempPath.appendingPathComponent(id + Self.videoFileExtension)
    }
}

extension FileManager {
    static func storeToTempDir(data: Data) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error writing to temp directory: \(error)")
            return fileURL // Return anyway, even though write failed
        }
    }
    
    static func copyToTempDir(url: URL) -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = url.lastPathComponent
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.copyItem(at: url, to: fileURL)
            return fileURL
        } catch {
            print("Error copying to temp directory: \(error)")
            return url // Return original on failure
        }
    }
}

