import SwiftUI
import UniformTypeIdentifiers

struct DocumentsPicker: View {
    @Binding var mediaItems: [MediaWithCaption]
    let maxCount: Int
    let onSend: ([MediaWithCaption]) -> Void
    let onFinish: () -> Void
    
    @State private var showDocumentPicker = true
    @State private var selectedDocuments: [URL] = []
    
    var body: some View {
        Group {
            if showDocumentPicker {
                DocumentPickerRepresentable(
                    selectedDocuments: $selectedDocuments,
                    onDismiss: {
                        if selectedDocuments.isEmpty {
                            onFinish()
                        } else {
                            processSelectedDocuments()
                            showDocumentPicker = false
                        }
                    }
                )
                .ignoresSafeArea()
            } else {
                // Selection view for reviewing and captioning
                MediaSelectionView(
                    mediaItems: $mediaItems,
                    maxCount: maxCount,
                    onAddMore: {
                        showDocumentPicker = true
                    },
                    onSend: onSend,
                    onFinish: onFinish
                )
            }
        }
    }
    
    private func processSelectedDocuments() {
        var newMediaItems: [MediaWithCaption] = []
        
        // Process each selected document
        for url in selectedDocuments {
            // Create a copy in temp directory to ensure access
            let tempURL = FileManager.copyToTempDir(url: url)
            
            // Create media model and add to collection
            let media = URLMediaModel(url: tempURL, type: .document)
            let mediaItem = MediaWithCaption(media: Media(source: media))
            newMediaItems.append(mediaItem)
            
            // Check if we've reached the max count
            if mediaItems.count + newMediaItems.count >= maxCount {
                break
            }
        }
        
        // Add the new items to our collection
        mediaItems.append(contentsOf: newMediaItems)
        
        // Reset selected documents
        selectedDocuments = []
    }
}

// Document picker wrapper
struct DocumentPickerRepresentable: UIViewControllerRepresentable {
    @Binding var selectedDocuments: [URL]
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Configure the document picker
        let supportedTypes: [UTType] = [.pdf, .plainText, .image, .movie, .spreadsheet, .presentation, .content]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerRepresentable
        
        init(_ parent: DocumentPickerRepresentable) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedDocuments = urls
            parent.onDismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDismiss()
        }
    }
}
