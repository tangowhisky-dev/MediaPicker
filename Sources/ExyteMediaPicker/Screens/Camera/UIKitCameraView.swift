import SwiftUI
import AVFoundation

public struct UIKitCameraView: UIViewControllerRepresentable {
    // Callbacks
    var onPhotoCapture: (URL) -> Void
    var onVideoCapture: (URL) -> Void
    var onCancel: () -> Void
    var onFlipCamera: () -> Void
    var onToggleFlash: () -> Void
    
    // State
    var flashEnabled: Bool
    
    public func makeUIViewController(context: Context) -> UIKitCameraViewController {
        let controller = UIKitCameraViewController()
        controller.onPhotoCapture = onPhotoCapture
        controller.onVideoCapture = onVideoCapture
        controller.onCancel = onCancel
        controller.onFlipCamera = onFlipCamera
        controller.onToggleFlash = onToggleFlash
        controller.flashEnabled = flashEnabled
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: UIKitCameraViewController, context: Context) {
        uiViewController.flashEnabled = flashEnabled
    }
}