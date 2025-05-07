import SwiftUI
import AVFoundation

struct CameraPicker: View {
    @Binding var mediaItems: [MediaWithCaption]
    let maxCount: Int
    let onSend: ([MediaWithCaption]) -> Void
    let onFinish: () -> Void
    
    @State private var showSelectionView = false
    
    var body: some View {
        ZStack {
            // If we have captured media, show the selection view
            if showSelectionView {
                MediaSelectionView(
                    mediaItems: $mediaItems,
                    maxCount: maxCount, 
                    onAddMore: {
                        showSelectionView = false
                    },
                    onSend: onSend,
                    onFinish: onFinish
                )
            } else {
                // Show camera view
                UIKitCameraView(
                    onPhotoCapture: { url in
                        handleCapturedMedia(url: url, type: .image)
                    },
                    onVideoCapture: { url in
                        handleCapturedMedia(url: url, type: .video)
                    },
                    onCancel: onFinish,
                    onFlipCamera: {},
                    onToggleFlash: {}
                )
                .ignoresSafeArea()
            }
        }
    }
    
    private func handleCapturedMedia(url: URL, type: MediaType) {
        // Create media from captured URL
        let media = URLMediaModel(url: url, type: type)
        
        // Add to mediaItems if we're under the limit
        if mediaItems.count < maxCount {
            mediaItems.append(MediaWithCaption(media: Media(source: media)))
            showSelectionView = true
        }
    }
}
