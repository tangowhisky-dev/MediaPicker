//
//  Created by Alex.M on 26.05.2022.
//

import SwiftUI
import UIKit

public struct SimplifiedMediaPicker: View {
    public typealias FilterClosure = @Sendable (Media) async -> Media?
    public typealias MassFilterClosure = @Sendable ([Media]) async -> [Media]

    // MARK: - Parameters

    @Binding private var isPresented: Bool
    private let onChange: MediaPickerCompletionClosure

    // MARK: - View builders

    // MARK: - Customization

    @Binding private var albums: [Album]
    @Binding private var currentFullscreenMediaBinding: Media?

    private var pickerMode: Binding<MediaPickerMode>?
    private var showingLiveCameraCell: Bool = false
    private var didPressCancelCamera: (() -> Void)?
    private var orientationHandler: MediaPickerOrientationHandler = {_ in}
    private var filterClosure: FilterClosure?
    private var massFilterClosure: MassFilterClosure?
    private var selectionParamsHolder = SelectionParamsHolder()

    // MARK: - Inner values

    @Environment(\.mediaPickerTheme) private var theme

    @StateObject private var viewModel = MediaPickerViewModel()
    @StateObject private var selectionService = SelectionService()
    @StateObject private var cameraSelectionService = CameraSelectionService()

    @State private var readyToShowCamera = false
    @State private var currentFullscreenMedia: Media?

    @State private var internalPickerMode: MediaPickerMode = .photos // a hack for slow camera dismissal

    var isInFullscreen: Bool {
        currentFullscreenMedia != nil
    }

    // MARK: - Object life cycle

    public init(isPresented: Binding<Bool>, onChange: @escaping MediaPickerCompletionClosure) {
        self._isPresented = isPresented
        self._albums = .constant([])
        self._currentFullscreenMediaBinding = .constant(nil)
        self.onChange = onChange
    }

    public var body: some View {
        Group {
            switch internalPickerMode { // please don't use viewModel.internalPickerMode here - it slows down camera dismissal
                case .photos, .albums, .album(_):
                    albumSelectionContainer
                case .camera:
                    cameraContainer
                case .cameraSelection:
                    cameraSelectionContainer
                }
        }
        .background(theme.main.pickerBackground.ignoresSafeArea())
        .environmentObject(selectionService)
        .environmentObject(cameraSelectionService)
        .onAppear {
            PermissionsService.shared.updatePhotoLibraryAuthorizationStatus()
#if !targetEnvironment(simulator)
            if showingLiveCameraCell {
                PermissionsService.shared.requestCameraPermission()
            } else {
                PermissionsService.shared.updateCameraAuthorizationStatus()
            }
#endif

            selectionService.onChange = onChange
            selectionService.mediaSelectionLimit = selectionParamsHolder.selectionLimit
            
            cameraSelectionService.onChange = onChange
            cameraSelectionService.mediaSelectionLimit = selectionParamsHolder.selectionLimit

            viewModel.shouldUpdatePickerMode = { mode in
                pickerMode?.wrappedValue = mode
            }
            viewModel.onStart()
        }
//        .onChange(of: viewModel.albums) { _ , albums in
//            self.albums = albums.map { $0.toAlbum() }
//        }
        .onChange(of: pickerMode?.wrappedValue) { _ , mode in
            if let mode = mode {
                viewModel.setPickerMode(mode)
            }
        }
        .onChange(of: viewModel.internalPickerMode) { _ , newValue in
            internalPickerMode = newValue
        }
        .onChange(of: currentFullscreenMedia) { 
            _currentFullscreenMediaBinding.wrappedValue = currentFullscreenMedia
        }
        .onAppear {
            if let mode = pickerMode?.wrappedValue {
                viewModel.setPickerMode(mode)
            }
        }
    }

    @ViewBuilder
    var albumSelectionContainer: some View {
//        let albumSelectionView = GalleryPicker(viewModel: viewModel, showingCamera: cameraBinding(), currentFullscreenMedia: $currentFullscreenMedia, showingLiveCameraCell: showingLiveCameraCell, selectionParamsHolder: selectionParamsHolder, filterClosure: filterClosure, massFilterClosure: massFilterClosure) {
//            // has media limit of 1, and it's been selected
//            isPresented = false
//        }
//        
//        VStack(spacing: 0) {
//            defaultHeaderView
//            albumSelectionView
//        }
    }

    @ViewBuilder
    var cameraSelectionContainer: some View {
        DefaultCameraSelectionContainer(
            viewModel: viewModel,
            showingPicker: $isPresented,
            selectionParamsHolder: selectionParamsHolder
        )
        .confirmationDialog("", isPresented: $viewModel.showingExitCameraConfirmation, titleVisibility: .hidden) {
            deleteAllButton
        }
    }

    @ViewBuilder
    var cameraContainer: some View {
        ZStack {
            theme.main.cameraBackground
                .ignoresSafeArea(.all)
                .onAppear {
                    DispatchQueue.main.async {
                        readyToShowCamera = true
                    }
                }
                .onDisappear {
                    readyToShowCamera = false
                }
            if readyToShowCamera {
                cameraSheet()
                    .confirmationDialog("", isPresented: $viewModel.showingExitCameraConfirmation, titleVisibility: .hidden) {
                        deleteAllButton
                    }
            }
        }
        .onAppear {
            orientationHandler(.lock)
        }
        .onDisappear {
            orientationHandler(.unlock)
        }
    }

    var deleteAllButton: some View {
        Button("Delete All") {
            cameraSelectionService.removeAll()
            viewModel.setPickerMode(.photos)
            onChange(selectionService.mapToMedia())
        }
    }

    var defaultHeaderView: some View {
        HStack {
            Button("Cancel") {
                selectionService.removeAll()
                cameraSelectionService.removeAll()
                isPresented = false
            }

            Spacer()

            Picker("", selection:
                    Binding(
                        get: { viewModel.internalPickerMode == .albums ? 1 : 0 },
                        set: { value in
                            viewModel.setPickerMode(value == 0 ? .photos : .albums)
                        }
                    )
            ) {
                Text("Photos")
                    .tag(0)
                Text("Albums")
                    .tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: UIScreen.main.bounds.width / 2)

            Spacer()

            Button("Done") {
                if selectionService.selected.isEmpty, let current = currentFullscreenMedia {
                    onChange([current])
                }
                isPresented = false
            }
        }
        .foregroundColor(theme.main.pickerText)
        .padding(12)
        .background(theme.defaultHeader.background)
    }

    func cameraBinding() -> Binding<Bool> {
        Binding(
            get: { viewModel.internalPickerMode == .camera },
            set: { value in
                if value { viewModel.setPickerMode(.camera) }
            }
        )
    }

    func modeBinding() -> Binding<Int> {
        Binding(
            get: { viewModel.internalPickerMode == .albums ? 1 : 0 },
            set: { value in
                viewModel.setPickerMode(value == 0 ? .photos : .albums)
            }
        )
    }

    @ViewBuilder
    private func cameraSheet() -> some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            CameraView(
                showPreviewClosure: {
                    withAnimation {
                        viewModel.setPickerMode(.cameraSelection)
                    }
                },
                didTakePicture: {
                    // This now just processes the captured photo
                    handleCapturedMedia()
                },
                didStartVideoRecording: { },
                didStopVideoRecording: { },
                toggleFlash: { },
                switchCamera: { },
                cancelClosure: cancel
            )
        }
    }

    private func handleCapturedMedia() {
        guard let url = viewModel.pickedMediaUrl else { return }
        
        // Create a media model from the URL
        let mediaModel = URLMediaModel(url: url)
        
        // Add to selection
        cameraSelectionService.onSelect(media: mediaModel)
    }
    
    private func cancel() {
        if cameraSelectionService.hasSelected {
            viewModel.showingExitCameraConfirmation = true
        } else {
            didPressCancelCamera?() ?? viewModel.setPickerMode(.photos)
        }
    }
}

// MARK: - Customization

public extension SimplifiedMediaPicker {

    func showLiveCameraCell(_ show: Bool = true) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker.showingLiveCameraCell = show
        return mediaPicker
    }

    func mediaSelectionType(_ type: MediaSelectionType) -> SimplifiedMediaPicker {
        selectionParamsHolder.mediaType = type
        return self
    }

    func mediaSelectionStyle(_ style: MediaSelectionStyle) -> SimplifiedMediaPicker {
        selectionParamsHolder.selectionStyle = style
        return self
    }

    func mediaSelectionLimit(_ limit: Int) -> SimplifiedMediaPicker {
        selectionParamsHolder.selectionLimit = limit
        return self
    }

    func showFullscreenPreview(_ show: Bool) -> SimplifiedMediaPicker {
        selectionParamsHolder.showFullscreenPreview = show
        return self
    }

    func setSelectionParameters(_ params: SelectionParamsHolder?) -> SimplifiedMediaPicker {
        guard let params = params else {
            return self
        }
        var mediaPicker = self
        mediaPicker.selectionParamsHolder = params
        return mediaPicker
    }

    func applyFilter(_ filterClosure: @escaping FilterClosure) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker.filterClosure = filterClosure
        return mediaPicker
    }

    func applyFilter(_ filterClosure: @escaping MassFilterClosure) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker.massFilterClosure = filterClosure
        return self
    }

    func didPressCancelCamera(_ didPressCancelCamera: @escaping ()->()) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker.didPressCancelCamera = didPressCancelCamera
        return mediaPicker
    }

    func orientationHandler(_ orientationHandler: @escaping MediaPickerOrientationHandler) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker.orientationHandler = orientationHandler
        return mediaPicker
    }

    func currentFullscreenMedia(_ currentFullscreenMedia: Binding<Media?>) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker._currentFullscreenMediaBinding = currentFullscreenMedia
        return mediaPicker
    }

    func albums(_ albums: Binding<[Album]>) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker._albums = albums
        return mediaPicker
    }

    func pickerMode(_ mode: Binding<MediaPickerMode>) -> SimplifiedMediaPicker {
        var mediaPicker = self
        mediaPicker.pickerMode = mode
        return mediaPicker
    }
}
