import SwiftUI
import AVFoundation

struct UIKitCameraView: UIViewControllerRepresentable {
    // Callbacks
    var onPhotoCapture: (URL) -> Void
    var onVideoCapture: (URL) -> Void
    var onCancel: () -> Void
    var onFlipCamera: () -> Void
    var onToggleFlash: () -> Void
    
    // State
    var flashEnabled: Bool = false
    
    func makeUIViewController(context: Context) -> UIKitCameraViewController {
        let controller = UIKitCameraViewController()
        controller.onPhotoCapture = onPhotoCapture
        controller.onVideoCapture = onVideoCapture
        controller.onCancel = onCancel
        controller.onFlipCamera = onFlipCamera
        controller.onToggleFlash = onToggleFlash
        controller.flashEnabled = flashEnabled
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIKitCameraViewController, context: Context) {
        uiViewController.flashEnabled = flashEnabled
    }
}

/// Adapter to bridge between SwiftUI camera interface and UIKit camera implementation
public struct UIKitCameraAdapter: View {
    // These closures come from MediaPicker and need to be called appropriately
    let cancelClosure: () -> Void
    let showPreviewClosure: () -> Void
    let takePhotoClosure: () -> Void
    let startVideoCaptureClosure: () -> Void
    let stopVideoCaptureClosure: () -> Void
    let toggleFlashClosure: () -> Void
    let flipCameraClosure: () -> Void
    
    // State for our UIKit camera
    @State private var flashEnabled: Bool = false
    
    // Add MediaPickerViewModel reference to match original flow
    @EnvironmentObject var viewModel: MediaPickerViewModel
    
    public init(
        cancelClosure: @escaping () -> Void,
        showPreviewClosure: @escaping () -> Void,
        takePhotoClosure: @escaping () -> Void,
        startVideoCaptureClosure: @escaping () -> Void,
        stopVideoCaptureClosure: @escaping () -> Void,
        toggleFlashClosure: @escaping () -> Void,
        flipCameraClosure: @escaping () -> Void
    ) {
        self.cancelClosure = cancelClosure
        self.showPreviewClosure = showPreviewClosure
        self.takePhotoClosure = takePhotoClosure
        self.startVideoCaptureClosure = startVideoCaptureClosure
        self.stopVideoCaptureClosure = stopVideoCaptureClosure
        self.toggleFlashClosure = toggleFlashClosure
        self.flipCameraClosure = flipCameraClosure
    }
    
    public var body: some View {
        UIKitCameraView(
            onPhotoCapture: { url in
                print("📸 UIKitCameraAdapter received photo URL: \(url.path)")
                
                // Match the original flow: set pickedMediaUrl directly
                DispatchQueue.main.async {
                    viewModel.pickedMediaUrl = url
                    showPreviewClosure()
                }
            },
            onVideoCapture: { url in
                // Same approach for video - directly update the view model
                DispatchQueue.main.async {
                    viewModel.pickedMediaUrl = url
                    showPreviewClosure()
                }
            },
            onCancel: cancelClosure,
            onFlipCamera: flipCameraClosure,
            onToggleFlash: {
                flashEnabled.toggle()
                toggleFlashClosure()
            },
            flashEnabled: flashEnabled
        )
        .ignoresSafeArea()
        .onAppear {
            print("UIKitCameraAdapter appeared")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("Camera permission granted: \(granted)")
            }
        }
    }
}

// Cache to temporarily store captured media URLs
public class URLMediaModelCache {
    public static let shared = URLMediaModelCache()
    public var latestCapturedURL: URL?
    
    private init() {}
}
