import SwiftUI
import PhotosUI

struct GalleryPicker: View {
    @Binding var mediaItems: [MediaWithCaption]
    let maxCount: Int
    let onSend: ([MediaWithCaption]) -> Void
    let onFinish: () -> Void
    
    @State private var selectedPhotos: [PHPickerResult] = []
    @State private var isLoading = false
    @State private var showPhotosPicker = true
    @State private var showPermissionDenied = false
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading media...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else if showPhotosPicker {
                PhotoPickerRepresentable(
                    selectedPhotos: $selectedPhotos,
                    maxSelectionCount: maxCount - mediaItems.count,
                    onDismiss: {
                        if selectedPhotos.isEmpty {
                            onFinish()
                        } else {
                            loadSelectedItems()
                        }
                    },
                    onPermissionDenied: {
                        showPermissionDenied = true
                    }
                )
                .ignoresSafeArea()
            } else {
                // Selection view for reviewing and captioning
                MediaSelectionView(
                    mediaItems: $mediaItems,
                    maxCount: maxCount,
                    onAddMore: {
                        showPhotosPicker = true
                    },
                    onSend: onSend,
                    onFinish: onFinish
                )
            }
            
            // Permission denied overlay
            if showPermissionDenied {
                VStack(spacing: 20) {
                    Image(systemName: "photo.badge.xmark")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Photos Access Required")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Please allow access to your photos to use this feature.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Cancel") {
                        onFinish()
                    }
                    .padding(.top)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7).ignoresSafeArea())
            }
        }
    }
    
    private func loadSelectedItems() {
        isLoading = true
        
        // Process each selected item
        let dispatchGroup = DispatchGroup()
        var newMediaItems: [MediaWithCaption] = []
        
        for result in selectedPhotos {
            dispatchGroup.enter()
            
            loadMediaItem(from: result) { mediaItem in
                if let mediaItem = mediaItem {
                    newMediaItems.append(mediaItem)
                }
                dispatchGroup.leave()
            }
        }
        
        // When all items are processed
        dispatchGroup.notify(queue: .main) {
            // Add new items to existing mediaItems
            mediaItems.append(contentsOf: newMediaItems)
            
            // Reset state
            selectedPhotos = []
            isLoading = false
            showPhotosPicker = false
        }
    }
    
    private func loadMediaItem(from pickerResult: PHPickerResult, completion: @escaping (MediaWithCaption?) -> Void) {
        // Check if the item is an image
        if pickerResult.itemProvider.canLoadObject(ofClass: UIImage.self) {
            pickerResult.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                if let image = object as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                    let tempURL = FileManager.storeToTempDir(data: data)
                    let media = URLMediaModel(url: tempURL, type: .image)
                    let mediaItem = MediaWithCaption(media: Media(source: media))
                    DispatchQueue.main.async {
                        completion(mediaItem)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
        // Check if the item is a video
        else if pickerResult.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            pickerResult.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let url = url {
                    let tempURL = FileManager.copyToTempDir(url: url)
                    let media = URLMediaModel(url: tempURL, type: .video)
                    let mediaItem = MediaWithCaption(media: Media(source: media))
                    DispatchQueue.main.async {
                        completion(mediaItem)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
}

// PHPicker wrapper
struct PhotoPickerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedPhotos: [PHPickerResult]
    let maxSelectionCount: Int
    let onDismiss: () -> Void
    let onPermissionDenied: () -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = maxSelectionCount
        configuration.filter = .any(of: [.images, .videos])
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerRepresentable
        
        init(_ parent: PhotoPickerRepresentable) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.selectedPhotos = results
            picker.dismiss(animated: true)
            
            // Check for permission denied
            if results.isEmpty {
                PHPhotoLibrary.requestAuthorization { status in
                    DispatchQueue.main.async {
                        if status == .denied || status == .restricted {
                            self.parent.onPermissionDenied()
                        } else {
                            self.parent.onDismiss()
                        }
                    }
                }
            } else {
                parent.onDismiss()
            }
        }
    }
}
