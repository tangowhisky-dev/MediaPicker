import SwiftUI
import Photos
import AVFoundation

public struct SimplifiedMediaPicker: View {
    // MARK: - Properties
    @Binding var isPresented: Bool
    @Binding var mediaItems: [MediaWithCaption]
    
    let maxCount: Int
    let onSend: ([MediaWithCaption]) -> Void
    
    @State private var selectedTab: PickerMode = .gallery
    @State private var showCancelConfirmation = false
    
    // MARK: - Initialization
    public init(
        isPresented: Binding<Bool>,
    @State private var documentsInitialized = false
    
    // MARK: - Initialization
    public init(
        isPresented: Binding<Bool>,
        mediaItems: Binding<[MediaWithCaption]>,
        maxCount: Int = 5,
        onSend: @escaping ([MediaWithCaption]) -> Void
    ) {
        self._isPresented = isPresented
        self._mediaItems = mediaItems
        self.maxCount = maxCount
        self.onSend = onSend
    }
    
    // MARK: - Body
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tab selector
                pickerModeTabs
                
                // Main content based on selected tab - using LazyView for performance
                tabContent
                    .edgesIgnoringSafeArea(.bottom)
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .confirmationDialog(
                "Discard selected media?",
                isPresented: $showCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    cleanupResources()
                    isPresented = false
                }
                Button("Keep Editing", role: .cancel) {
                    showCancelConfirmation = false
                }
            }
        }
        .onAppear {
            // Initialize only the first tab on appear
            switch selectedTab {
            case .camera: cameraInitialized = true
            case .gallery: galleryInitialized = true
            case .documents: documentsInitialized = true
            }
        }
        .onDisappear {
            cleanupResources()
        }
    }
    
    // MARK: - UI Components
    
    private var headerView: some View {
        HStack {
            // Cancel button
            Button(action: {
                if !mediaItems.isEmpty {
                    showCancelConfirmation = true
                } else {
                    cleanupResources()
                    isPresented = false
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                    Text("Cancel")
                }
                .foregroundColor(.teal)
            }
            
            Spacer()
            
            // Selected count
            Text("\(mediaItems.count) of \(maxCount) selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Save button
            Button(action: { 
                cleanupResources()
                isPresented = false 
            }) {
                Text("Save")
                    .fontWeight(.semibold)
                    .foregroundColor(.teal)
            }
            .opacity(mediaItems.isEmpty ? 0.5 : 1)
            .disabled(mediaItems.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var pickerModeTabs: some View {
        HStack(spacing: 0) {
            ForEach(PickerMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation {
                        selectedTab = mode
                    }
                    
                    // Just-in-time initialization of tab content
                    switch mode {
                    case .camera: cameraInitialized = true
                    case .gallery: galleryInitialized = true
                    case .documents: documentsInitialized = true
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 22))
                        Text(mode.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selectedTab == mode ? .teal : .gray)
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .camera:
            if cameraInitialized {
                CameraPicker(
                    mediaItems: $mediaItems,
                    maxCount: maxCount,
                    onSend: onSend,
                    onFinish: { isPresented = false }
                )
                .transition(.opacity)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
            
        case .gallery:
            if galleryInitialized {
                GalleryPicker(
                    mediaItems: $mediaItems,
                    maxCount: maxCount,
                    onSend: onSend,
                    onFinish: { isPresented = false }
                )
                .transition(.opacity)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
            
        case .documents:
            if documentsInitialized {
                DocumentsPicker(
                    mediaItems: $mediaItems,
                    maxCount: maxCount,
                    onSend: onSend,
                    onFinish: { isPresented = false }
                )
                .transition(.opacity)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func cleanupResources() {
        // Post a notification to clean up resources
        NotificationCenter.default.post(
            name: NSNotification.Name("ReleaseCameraResources"), 
            object: nil
        )
    }
}

// MARK: - Supporting Types
public enum PickerMode: CaseIterable {
    case camera
    case gallery
    case documents
    
    var title: String {
        switch self {
        case .camera: return "Camera"
        case .gallery: return "Photos"
        case .documents: return "Files"
        }
    }
    
    var icon: String {
        switch self {
        case .camera: return "camera"
        case .gallery: return "photo.on.rectangle"
        case .documents: return "doc"
        }
    }
}

// Helper type for lazy initialization of views - avoids creating views until needed
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}
