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
    private var currentVideoURL: URL?
    private var isPhotoMode = true
    private var gridOverlayView: UIView?
    
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
    
    private lazy var gridButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "grid"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(gridButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 3
        button.layer.cornerRadius = 35
        
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
        
        // Add and position UI components
        [cancelButton, flashButton, flipButton, gridButton, captureButton, modeSegmentedControl, recordingIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // Position controls
        NSLayoutConstraint.activate([
            // Top row
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            flashButton.topAnchor.constraint(equalTo: cancelButton.topAnchor),
            flashButton.trailingAnchor.constraint(equalTo: gridButton.leadingAnchor, constant: -20),
            
            gridButton.topAnchor.constraint(equalTo: cancelButton.topAnchor),
            gridButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
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
        if isPhotoMode {
            capturePhoto()
        } else {
            if isRecording {
                stopVideoRecording()
            } else {
                startVideoRecording()
            }
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
    
    // MARK: - Camera Functions
    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
        // Apply flash settings if device supports it
        if let device = videoDeviceInput?.device, device.hasFlash {
            settings.flashMode = flashEnabled ? .on : .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
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
}

// MARK: - AVCapturePhotoCaptureDelegate
extension UIKitCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error getting image data")
            return
        }
        
        // Save to temp file
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try imageData.write(to: fileURL)
            onPhotoCapture?(fileURL)
        } catch {
            print("Error writing image to file: \(error)")
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