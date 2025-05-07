import SwiftUI
import AVKit

struct MediaSelectionView: View {
    @Binding var mediaItems: [MediaWithCaption]
    let maxCount: Int
    let onAddMore: () -> Void
    let onSend: ([MediaWithCaption]) -> Void
    let onFinish: () -> Void
    
    @State private var currentIndex = 0
    @State private var textEditorHeights: [CGFloat] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Media preview area
            TabView(selection: $currentIndex) {
                ForEach(mediaItems.indices, id: \.self) { index in
                    VStack {
                        MediaPreviewView(media: mediaItems[index].media)
                            .aspectRatio(contentMode: .fit)
                            .padding(10)
                            .contentShape(Rectangle())
                            .onTapGesture { hideKeyboard() }
                            .onAppear {
                                if textEditorHeights.count <= index {
                                    textEditorHeights = Array(repeating: 40, count: mediaItems.count)
                                }
                            }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
            
            Spacer()
            
            // Caption editor and controls
            VStack(spacing: 10) {
                if !mediaItems.isEmpty, currentIndex < mediaItems.count {
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: textEditorHeights[safe: currentIndex] ?? 40 > 70 ? 10 : 20)
                            .fill(Color.white)
                            .shadow(radius: 2)
                            .frame(height: max(65, textEditorHeights[safe: currentIndex] ?? 40))
                        
                        HStack(alignment: .center, spacing: 8) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: Binding(
                                    get: { mediaItems[safe: currentIndex]?.caption ?? "" },
                                    set: { 
                                        if currentIndex < mediaItems.count { 
                                            mediaItems[currentIndex].caption = $0 
                                            updateTextEditorHeight(for: currentIndex, text: $0)
                                        } 
                                    }
                                ))
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                                .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                                .frame(height: max(textEditorHeights[safe: currentIndex] ?? 40, 40))
                                .background(Color.clear)
                                .onAppear {
                                    UITextView.appearance().backgroundColor = .clear
                                    updateTextEditorHeight(for: currentIndex, text: mediaItems[safe: currentIndex]?.caption ?? "")
                                }
                                
                                if mediaItems[safe: currentIndex]?.caption.isEmpty ?? true {
                                    Text("Add caption...")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                        .padding(.top, 16)
                                        .padding(.leading, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                onSend(mediaItems)
                                onFinish()
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .padding(14)
                                    .background(Color.teal)
                                    .clipShape(Circle())
                                    .foregroundColor(.white)
                                    .overlay(
                                        Text("\(mediaItems.count)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                            .offset(x: -5, y: -5),
                                        alignment: .topLeading
                                    )
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .animation(.easeInOut(duration: 0.2), value: textEditorHeights[safe: currentIndex])
                }
                
                // Add more button
                Button(action: onAddMore) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 18))
                        Text("Add more")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.teal)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .disabled(mediaItems.count >= maxCount)
                .opacity(mediaItems.count >= maxCount ? 0.5 : 1)
            }
            .padding(.vertical, 5)
            .padding(.horizontal)
            .background(Color(.systemBackground).opacity(0.95))
        }
    }
    
    private func updateTextEditorHeight(for index: Int, text: String) {
        guard index < textEditorHeights.count else { return }
        
        let size = CGSize(width: UIScreen.main.bounds.width - 60, height: .greatestFiniteMagnitude)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18)
        ]
        
        let estimatedSize = NSString(string: text).boundingRect(
            with: size,
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        ).size
        
        let maxHeight: CGFloat = 120
        let newHeight = min(maxHeight, max(40, estimatedSize.height + 20))
        
        if abs(textEditorHeights[index] - newHeight) > 1 {
            textEditorHeights[index] = newHeight
        }
    }
}

// Media preview component
struct MediaPreviewView: View {
    let media: Media
    @State private var image: UIImage? = nil
    @State private var player: AVPlayer? = nil

    var body: some View {
        Group {
            if media.type == .image {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            } else if media.type == .video {
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fit)
                        .onDisappear {
                            player.pause()
                        }
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            } else {
                // Document preview
                documentPreview
            }
        }
        .onAppear {
            loadMedia()
        }
        .id(media.id)
    }
    
    private var documentPreview: some View {
        VStack {
            Image(systemName: "doc")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
            
            Text(media.getURL() != nil ? (try? await media.getURL()?.lastPathComponent) ?? "Document" : "Document")
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    private func loadMedia() {
        Task {
            if media.type == .image {
                if let data = await media.getData(),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        self.image = img
                    }
                }
            } else if media.type == .video {
                if let url = await media.getURL() {
                    let asset = AVAsset(url: url)
                    let playerItem = AVPlayerItem(asset: asset)
                    await MainActor.run {
                        self.player = AVPlayer(playerItem: playerItem)
                    }
                }
            }
        }
    }
}
