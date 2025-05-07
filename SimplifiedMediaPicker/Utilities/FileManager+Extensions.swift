import Foundation
import UIKit

extension FileManager {
    static func getTempUrl() -> URL {
        let directory = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString
        return directory.appendingPathComponent(fileName)
    }
    
    static func storeToTempDir(data: Data) -> URL {
        let url = getTempUrl()
        try? data.write(to: url)
        return url
    }
    
    static func copyToTempDir(url: URL) -> URL {
        let tempUrl = getTempUrl().appendingPathExtension(url.pathExtension)
        try? FileManager.default.copyItem(at: url, to: tempUrl)
        return tempUrl
    }
}

// Collection safe access
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// Hide keyboard helper
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
