import UIKit
import AVFoundation
import SwiftUI

class UIKitCameraViewController: UIViewController {
    // MARK: - Public properties and callbacks
    var onPhotoCapture: ((URL) -> Void)?
    var onVideoCapture: ((URL) -> Void)?
    var onCancel: (() -> Void)?
    var onFlipCamera: (() -> Void)?
    var onToggleFlash: (() -> Void)?
    var flashEnabled: Bool = false
    
    // MARK: - Private properties
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureMovieFileOutput()
    private var isRecording = false
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var recordingTimer: Timer?
    private var recordingDuration: TimeInterval = 0
    private var isPhotoMode = true
    private var isCameraButtonEnabled = true
    
    // MARK: - UI Components
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var flashButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var flipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(flipButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 3
        button.layer.cornerRadius = 35
        
        // Inner circle
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30
        button.addSubview(innerCircle)
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            innerCircle.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        button.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var modeSegmentedControl: UISegmentedControl = {
        let segmentedControl = UISegmentedControl(items: ["PHOTO", "VIDEO"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentedControl.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.3)
        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        return segmentedControl
    }()
    
    private lazy var recordingIndicator: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }
    
    // MARK: - Setup Methods
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            return
        }
        videoDeviceInput = videoInput
        captureSession.addInput(videoInput)
        
        // Add audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        
        // Add photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        
        // Add video output
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        captureSession.commitConfiguration()
    }
    
    private func setupUI() {
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        
        // Add UI components
        [cancelButton, flashButton, flipButton, captureButton, modeSegmentedControl, recordingIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // Position controls
        NSLayoutConstraint.activate([
            // Top row
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            flashButton.topAnchor.constraint(equalTo: cancelButton.topAnchor),
            flashButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            recordingIndicator.topAnchor.constraint(equalTo: cancelButton.topAnchor),
            recordingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordingIndicator.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            // Bottom controls
            modeSegmentedControl.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -30),
            modeSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSegmentedControl.widthAnchor.constraint(equalToConstant: 160),
            
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),
            
            flipButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            flipButton.leadingAnchor.constraint(equalTo: captureButton.trailingAnchor, constant: 50)
        ])
    }
    
    // MARK: - Session Management
    private func startCaptureSession() {
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    private func stopCaptureSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Camera Actions
    @objc private func captureButtonTapped() {
        guard isCameraButtonEnabled else { return }
        isCameraButtonEnabled = false
        
        if isPhotoMode {
            animateCaptureButtonPress()
            capturePhoto()
        } else {
            if isRecording {
                stopVideoRecording()
            } else {
                startVideoRecording()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isCameraButtonEnabled = true
        }
    }
    
    @objc private func flashButtonTapped() {
        flashEnabled.toggle()
        toggleFlash(flashEnabled)
        onToggleFlash?()
        flashButton.setImage(UIImage(systemName: flashEnabled ? "bolt.fill" : "bolt.slash"), for: .normal)
    }
    
    @objc private func flipButtonTapped() {
        flipCamera()
        onFlipCamera?()
    }
    
    @objc private func cancelButtonTapped() {
        onCancel?()
    }
    
    @objc private func modeChanged(_ sender: UISegmentedControl) {
        isPhotoMode = sender.selectedSegmentIndex == 0
        updateCaptureButtonAppearance()
    }
    
    // MARK: - Camera Functions
    private func capturePhoto() {
        showCameraSnapshot()
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashEnabled ? .on : .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
        debugLabel.textColor = .white
        debugLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        debugLabel.textAlignment = .center
        debugLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        debugLabel.frame = CGRect(x: 0, y: 100, width: 200, height: 40)
        debugLabel.center.x = self.view.center.x
        debugLabel.layer.cornerRadius = 8
        debugLabel.clipsToBounds = true
        view.addSubview(debugLabel)
        
        // Remove after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIView.animate(withDuration: 0.3) {
                debugLabel.alpha = 0
            } completion: { _ in
                debugLabel.removeFromSuperview()
            }
        }
        
        // Proceed with photo capture
        guard isCameraButtonEnabled else { 
            print("⚠️ Camera button is disabled")
            return 
        }
        
        isCameraButtonEnabled = false
        
        if isPhotoMode {
            animateCaptureButtonPress()
            capturePhoto()
        } else {
            if isRecording {
                stopVideoRecording()
            } else {
                startVideoRecording()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isCameraButtonEnabled = true
        }
    }
    
    @objc private func flashButtonTapped() {
        flashEnabled.toggle()
        toggleFlash(flashEnabled)
        onToggleFlash?()
        
        // Update UI
        flashButton.setImage(UIImage(systemName: flashEnabled ? "bolt.fill" : "bolt.slash"), for: .normal)
    }
    
    @objc private func flipButtonTapped() {
        flipCamera()
        onFlipCamera?()
    }
    
    @objc private func cancelButtonTapped() {
        onCancel?()
    }
    
    @objc private func gridButtonTapped() {
        toggleGridOverlay()
    }
    
    @objc private func modeChanged(_ sender: UISegmentedControl) {
        isPhotoMode = sender.selectedSegmentIndex == 0
        updateCaptureButtonAppearance()
    }
    
    @objc private func buttonTouchDown() {
        print("👆 Touch DOWN on camera button")
        // Flash the button briefly to show touch was received
        UIView.animate(withDuration: 0.1) {
            self.captureButton.alpha = 0.7
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.alpha = 1.0
            }
        }
    }
    
    // MARK: - Camera Functions
    private func capturePhoto() {
        guard captureSession.isRunning else {
            print("⚠️ Error: Camera session not running")
            return
        }
        
        print("📸 Taking photo with photoOutput settings: \(photoOutput.availablePhotoCodecTypes)")
        print("📸 Connection active? \(photoOutput.connection(with: .video)?.isActive ?? false)")
        
        // Add extra debug print about connections
        let connections = photoOutput.connections.map { $0.inputPorts.map(\.mediaType) }
        print("📸 Available connections: \(connections)")
        
        showCameraSnapshot()
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashEnabled ? .on : .off
        
        // Try-catch for capturing to see if there are errors
        do {
            photoOutput.capturePhoto(with: settings, delegate: self)
            print("📸 Photo capture requested")
        } catch {
            print("⚠️ Error requesting photo capture: \(error)")
        }
    }
    
    private func startVideoRecording() {
        guard !isRecording else { return }
        
        // Create URL for recording
        let outputPath = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        currentVideoURL = outputPath
        
        // Start recording
        videoOutput.startRecording(to: outputPath, recordingDelegate: self)
        isRecording = true
        
        // Update UI for recording state
        updateCaptureButtonAppearance()
        startRecordingTimer()
    }
    
    private func stopVideoRecording() {
        guard isRecording else { return }
        
        videoOutput.stopRecording()
        isRecording = false
        
        // Update UI
        updateCaptureButtonAppearance()
        stopRecordingTimer()
    }
    
    private func toggleFlash(_ on: Bool) {
        guard let device = videoDeviceInput?.device, device.hasFlash else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.hasTorch && !isPhotoMode {
                device.torchMode = on ? .on : .off
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error toggling flash: \(error)")
        }
    }
    
    private func flipCamera() {
        // Get current position
        let currentPosition = videoDeviceInput?.device.position
        
        // Find new position
        let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
        
        // Get new device
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newVideoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }
        
        // Update session
        captureSession.beginConfiguration()
        
        if let videoDeviceInput = videoDeviceInput {
            captureSession.removeInput(videoDeviceInput)
        }
        
        if captureSession.canAddInput(newVideoInput) {
            captureSession.addInput(newVideoInput)
            self.videoDeviceInput = newVideoInput
        }
        
        captureSession.commitConfiguration()
    }
    
    private func toggleGridOverlay() {
        if gridOverlayView != nil {
            gridOverlayView?.removeFromSuperview()
            gridOverlayView = nil
            gridButton.tintColor = .white
        } else {
            let gridView = createGridOverlay()
            view.addSubview(gridView)
            gridOverlayView = gridView
            view.bringSubviewToFront(gridView)
            gridButton.tintColor = .yellow
        }
    }
    
    private func createGridOverlay() -> UIView {
        let gridView = UIView(frame: view.bounds)
        gridView.backgroundColor = .clear
        gridView.isUserInteractionEnabled = false // CRITICAL FIX: Make grid non-interactive
        
        // Create horizontal lines
        for i in 1...2 {
            let y = view.bounds.height / 3.0 * CGFloat(i)
            let lineView = UIView(frame: CGRect(x: 0, y: y, width: view.bounds.width, height: 0.5))
            lineView.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            gridView.addSubview(lineView)
        }
        
        // Create vertical lines
        for i in 1...2 {
            let x = view.bounds.width / 3.0 * CGFloat(i)
            let lineView = UIView(frame: CGRect(x: x, y: 0, width: 0.5, height: view.bounds.height))
            lineView.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            gridView.addSubview(lineView)
        }
        
        return gridView
    }
    
    // MARK: - Recording Timer
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingIndicator.isHidden = false
        updateRecordingTimerDisplay()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
            self?.updateRecordingTimerDisplay()
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingIndicator.isHidden = true
    }
    
    private func updateRecordingTimerDisplay() {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        recordingIndicator.text = String(format: "● %02d:%02d", minutes, seconds)
    }
    
    private func updateCaptureButtonAppearance() {
        if isPhotoMode {
            // Photo mode appearance
            captureButton.subviews.first?.backgroundColor = .white
            
            if let innerCircle = captureButton.subviews.first {
                innerCircle.layer.cornerRadius = 30
            }
        } else {
            // Video mode appearance
            if isRecording {
                // Recording indicator (red circle with white square)
                captureButton.subviews.first?.backgroundColor = .red
                
                if let innerCircle = captureButton.subviews.first {
                    innerCircle.layer.cornerRadius = 30
                    
                    // Add white square in center if not already there
                    if innerCircle.subviews.isEmpty {
                        let stopIndicator = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
                        stopIndicator.backgroundColor = .white
                        stopIndicator.layer.cornerRadius = 3
                        innerCircle.addSubview(stopIndicator)
                        stopIndicator.center = CGPoint(x: innerCircle.bounds.width/2, y: innerCircle.bounds.height/2)
                    }
                }
            } else {
                // Ready to record (red circle)
                captureButton.subviews.first?.backgroundColor = .red
                
                if let innerCircle = captureButton.subviews.first {
                    innerCircle.layer.cornerRadius = 30
                    innerCircle.subviews.forEach { $0.removeFromSuperview() }
                }
            }
        }
    }
    
    // Add snapshot animation
    private func showCameraSnapshot() {
        // Create white overlay for flash effect
        let snapshotView = UIView(frame: view.bounds)
        snapshotView.backgroundColor = UIColor.white
        snapshotView.alpha = 0.0
        view.addSubview(snapshotView)
        self.snapshotView = snapshotView
        
        // Animate flash effect
        UIView.animate(withDuration: 0.2, animations: {
            snapshotView.alpha = 0.8
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                snapshotView.alpha = 0.0
            } completion: { _ in
                snapshotView.removeFromSuperview()
                self.snapshotView = nil
            }
        })
    }
    
    // Animate the capture button when pressed
    private func animateCaptureButtonPress() {
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = CGAffineTransform.identity
            }
        })
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension UIKitCameraViewController: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("📸 Photo processing completed")
        
        if let error = error {
            print("⚠️ Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("⚠️ Error: Could not get image data")
            return
        }
        
        // Save to temporary file
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            print("📸 Photo saved to: \(fileURL.path)")
            
            // Call the callback on main thread
            DispatchQueue.main.async {
                self.onPhotoCapture?(fileURL)
            }
        } catch {
            print("⚠️ Error saving photo: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension UIKitCameraViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        isRecording = false
        updateCaptureButtonAppearance()
        
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            return
        }
        
        onVideoCapture?(outputFileURL)
    }
}