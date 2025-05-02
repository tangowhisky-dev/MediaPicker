//
//  CameraViewModel.swift
//  
//
//  Created by Alexandra Afonasova on 18.10.2022.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine

#if compiler(>=6.0)
extension AVCaptureSession: @retroactive @unchecked Sendable { }
#else
extension AVCaptureSession: @unchecked Sendable { }
#endif

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight // Device left = camera right
        case .landscapeRight: return .landscapeLeft // Device right = camera left
        default: return nil
        }
    }
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return nil
        }
    }
}

final actor CameraViewModel: NSObject, ObservableObject {

    struct CaptureDevice {
        let device: AVCaptureDevice
        let position: AVCaptureDevice.Position
        let defaultZoom: CGFloat
        let maxZoom: CGFloat
    }

    @MainActor @Published private(set) var flashEnabled = false
    @MainActor @Published private(set) var snapOverlay = false
    @MainActor @Published private(set) var zoomAllowed = false
    @MainActor @Published private(set) var capturedPhoto: URL?

    let captureSession = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureMovieFileOutput()
    private let motionManager = MotionManager()
    private var captureDevice: CaptureDevice?
    private var lastPhotoActualOrientation: UIDeviceOrientation?
    private var orientationObserver: Any?

    private let minScale: CGFloat = 1
    private let singleCameraMaxScale: CGFloat = 5
    private let dualCameraMaxScale: CGFloat = 8
    private let tripleCameraMaxScale: CGFloat = 12
    private var lastScale: CGFloat = 1

    override init() {
        super.init()
        Task {
            await configureSession()
            captureSession.startRunning()
        }

        // Start observing device orientation changes
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCameraForNewOrientation()
        }

        // Begin generating orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    deinit {
        if let observer = orientationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func startSession() {
        captureSession.startRunning()
    }

    func stopSession() {
        captureSession.stopRunning()
    }

    func setCapturedPhoto(_ photo: URL?) {
        DispatchQueue.main.async {
            self.capturedPhoto = photo
        }
    }

    func takePhoto() async {
        // Show snapshot animation
        showSnapshot()
        
        // Set correct orientation for photo capture
        let photoSettings = AVCapturePhotoSettings()
        
        if let photoOutputConnection = photoOutput.connection(with: .video) {
            // Get current device orientation
            let currentOrientation = UIDevice.current.orientation
            if let videoOrientation = currentOrientation.videoOrientation {
                photoOutputConnection.videoOrientation = videoOrientation
            } else {
                photoOutputConnection.videoOrientation = .portrait // Fallback to portrait
            }
        }
        
        if await flashEnabled {
            photoSettings.flashMode = .on
        }
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }

    private func showSnapshot() {
        Task { @MainActor in
            // Set overlay to true to show the animation
            self.snapOverlay = true
            
            // Reset the overlay after a short delay
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            self.snapOverlay = false
        }
    }

    func startVideoCapture() async {
        // Set flash if needed
        setVideoTorchMode(await flashEnabled ? .on : .off)
        
        // IMPROVEMENT: Add a tiny delay to ensure orientation updates have propagated
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Set correct orientation before recording
        if let connection = videoOutput.connection(with: .video) {
            // Get current device orientation
            let currentOrientation = UIDevice.current.orientation
            if let videoOrientation = currentOrientation.videoOrientation {
                connection.videoOrientation = videoOrientation
            } else {
                // Try getting orientation from window as backup
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let videoOrientation = windowScene.interfaceOrientation.videoOrientation {
                    connection.videoOrientation = videoOrientation
                } else {
                    connection.videoOrientation = .portrait // Fallback to portrait
                }
            }
        }
        
        let videoUrl = FileManager.getTempUrl()
        videoOutput.startRecording(to: videoUrl, recordingDelegate: self)
    }

    func stopVideoCapture() {
        setVideoTorchMode(.off)
        videoOutput.stopRecording()
    }

    func setVideoTorchMode(_ mode: AVCaptureDevice.TorchMode) {
        if captureDevice?.device.torchMode != mode {
            try? captureDevice?.device.lockForConfiguration()
            captureDevice?.device.torchMode = mode
            captureDevice?.device.unlockForConfiguration()
        }
    }

    func flipCamera() {
        let session = captureSession
        guard let input = session.inputs.first else {
            return
        }
        let newPosition: AVCaptureDevice.Position = captureDevice?.position == .back ? .front : .back

        session.beginConfiguration()
        session.removeInput(input)
        addInput(to: session, for: newPosition)
        session.commitConfiguration()
    }

    func toggleFlash() {
        DispatchQueue.main.async {
            self.flashEnabled.toggle()
        }
    }

    nonisolated func zoomChanged(_ scale: CGFloat) {
        Task {
            await zoomCamera(await resolveScale(scale))
        }
    }

    nonisolated func zoomEnded(_ scale: CGFloat) {
        Task {
            await setLastScale(await resolveScale(scale))
            await zoomCamera(lastScale)
        }
    }

    private func setLastScale(_ scale: CGFloat) {
        self.lastScale = scale
    }

    private func resolveScale(_ gestureScale: CGFloat) -> CGFloat {
        let newScale = lastScale * gestureScale
        let maxScale = captureDevice?.maxZoom ?? singleCameraMaxScale
        return max(min(maxScale, newScale), minScale)
    }

    private func zoomCamera(_ scale: CGFloat) {
        do {
            try captureDevice?.device.lockForConfiguration()
            captureDevice?.device.videoZoomFactor = scale
            captureDevice?.device.unlockForConfiguration()
        } catch {}
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        addInput(to: captureSession)
        addOutput(to: captureSession)
        captureSession.commitConfiguration()
    }

    private func addInput(to session: AVCaptureSession, for position: AVCaptureDevice.Position = .back) {
        guard let captureDevice = selectCaptureDevice(for: position) else { return }
        let zoomAllowed = captureDevice.position == .back
        Task { @MainActor in
            self.zoomAllowed = zoomAllowed
        }
        guard let captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        guard session.canAddInput(captureDeviceInput) else { return }
        session.addInput(captureDeviceInput)

        guard let captureAudioDevice = selectAudioCaptureDevice() else { return }
        guard let captureAudioDeviceInput = try? AVCaptureDeviceInput(device: captureAudioDevice) else { return }
        guard session.canAddInput(captureAudioDeviceInput) else { return }
        session.addInput(captureAudioDeviceInput)

        let defaultZoom = CGFloat(truncating: captureDevice.virtualDeviceSwitchOverVideoZoomFactors.first ?? minScale as NSNumber)

        let maxZoom: CGFloat
        let cameraCount = captureDevice.virtualDeviceSwitchOverVideoZoomFactors.count + 1
        switch cameraCount {
        case 1: maxZoom = singleCameraMaxScale
        case 2: maxZoom = dualCameraMaxScale
        default: maxZoom = tripleCameraMaxScale
        }

        let device = CaptureDevice(
            device: captureDevice,
            position: position,
            defaultZoom: defaultZoom,
            maxZoom: maxZoom
        )
        self.captureDevice = device

        if position == .back {
            captureDeviceInput.device.videoZoomFactor = device.defaultZoom
            lastScale = device.defaultZoom
        }
    }

    private func addOutput(to session: AVCaptureSession) {
        photoOutput.isLivePhotoCaptureEnabled = false
        guard session.canAddOutput(photoOutput) else { return }
        session.addOutput(photoOutput)

        guard session.canAddOutput(videoOutput) else { return }
        session.addOutput(videoOutput)

        updateOutputOrientation(photoOutput)
        updateOutputOrientation(videoOutput)
    }

    private func updateOutputOrientation(_ output: AVCaptureOutput) {
        guard let connection = output.connection(with: .video) else { return }
        
        // Support orientation changes
        if connection.isVideoOrientationSupported {
            if let videoOrientation = UIDevice.current.orientation.videoOrientation {
                connection.videoOrientation = videoOrientation
            } else {
                connection.videoOrientation = .portrait
            }
        }
        
        // Original rotation angle code
        if connection.isVideoRotationAngleSupported(0) {
            connection.videoRotationAngle = 0
        }
    }

    private func selectCaptureDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera,
                .builtInTelephotoCamera,
                .builtInTrueDepthCamera,
                .builtInUltraWideCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: position)

        if let camera = session.devices.first(where: { $0.deviceType == .builtInTripleCamera }) {
            return camera
        } else if let camera = session.devices.first(where: { $0.deviceType == .builtInDualCamera }) {
            return camera
        } else {
            return session.devices.first
        }
    }

    private func selectAudioCaptureDevice() -> AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified)

        return session.devices.first
    }

    private func updateCameraForNewOrientation() {
        // Update preview layer orientation
        DispatchQueue.main.async {
            // Update video connection orientation for future recordings
            if let connection = self.videoOutput.connection(with: .video),
               let orientation = UIDevice.current.orientation.videoOrientation {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = orientation
                }
            }
            
            // Also update photo orientation
            if let connection = self.photoOutput.connection(with: .video),
               let orientation = UIDevice.current.orientation.videoOrientation {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = orientation
                }
            }
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let cgImage = photo.cgImageRepresentation() else { return }

        Task {
            let photoOrientation: UIImage.Orientation
            if let orientation = await lastPhotoActualOrientation {
                photoOrientation = UIImage.Orientation(orientation)
            } else {
                photoOrientation = UIImage.Orientation.default
            }

            guard let data = UIImage(
                cgImage: cgImage,
                scale: 1,
                orientation: photoOrientation
            ).jpegData(compressionQuality: 0.8) else { return }

            await setCapturedPhoto(FileManager.storeToTempDir(data: data))
        }
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task {
            await setCapturedPhoto(outputFileURL)
        }
    }
}
