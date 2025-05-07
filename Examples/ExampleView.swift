/*
import SwiftUI
import ExyteMediaPicker

struct ExampleView: View {
    @State private var showMediaPicker = false
    @State private var selectedMedia: [MediaWithCaption] = []
    
    var body: some View {
        VStack {
            // Display selected media items
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                    ForEach(selectedMedia, id: \.id) { media in
                        mediaPreview(for: media)
                            .frame(height: 100)
                            .clipped()
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Button to show media picker
            Button("Select Media") {
                showMediaPicker = true
            }
            .padding()
            .sheet(isPresented: $showMediaPicker) {
                SimplifiedMediaPicker(
                    isPresented: $showMediaPicker,
                    mediaItems: $selectedMedia,
                    maxCount: 5,
                    onSend: handleMediaSelection
                )
            }
        }
    }
    
    // Handle selected media
    func handleMediaSelection(_ media: [MediaWithCaption]) {
        print("Selected \(media.count) media items")
        // Process the media items as needed
    }
    
    // Preview for selected media items
    @ViewBuilder
    func mediaPreview(for media: MediaWithCaption) -> some View {
        switch media.type {
        case .image:
            if let uiImage = media.thumbnail {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
            }
        case .video:
            ZStack {
                if let thumbnail = media.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                Image(systemName: "play.circle")
                    .font(.largeTitle)
            }
        case .document:
            VStack {
                Image(systemName: "doc")
                    .font(.largeTitle)
                Text(media.filename ?? "Document")
                    .lineLimit(1)
                    .font(.caption)
            }
        }
    }
}
*/
