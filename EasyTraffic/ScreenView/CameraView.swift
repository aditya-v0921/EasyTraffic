import SwiftUI
import AVFoundation
import AVKit
import Vision

// MARK: - SwiftUI Wrapper for Camera

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onDismiss = {
            dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // Nothing to update
    }
}

// MARK: - Camera View Controller

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var classificationLabel = UILabel()
    var onDismiss: (() -> Void)?
    
    private let announcer = Announcer.shared
    private let deduper = Deduper()
    private let stability = StabilityGate()
    private let minConfidence: Float = 0.65
    private let visionQueue = DispatchQueue(label: "easytraffic.visionQueue", qos: .userInitiated)
    private lazy var visionModel: VNCoreMLModel? = try? VNCoreMLModel(for: SS1().model)
    private var isProcessingFrame = false
    private var lastFrameProcessedAt: Date = .distantPast
    private let frameProcessingInterval: TimeInterval = 0.35
    private var speedTimer: Timer?
    
    // NEW: Drive tracking and motion detection
    private let driveManager = FirebaseDriveManager.shared
    private let motionDetector = MotionDetector()
    private var hasDriveStarted = false
    
    private let dashboardOverlay = UIView()
    private let speedLabel = UILabel()
    private let speedCaptionLabel = UILabel()
    private let driveStatusLabel = UILabel()
    private let alertTitleLabel = UILabel()
    private let alertDetailLabel = UILabel()
    private let confidenceLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupDashboard()
        
        // Start motion detection
        motionDetector.startMonitoring()
        startDashboardUpdates()
        
        // Start drive session
        Task {
            if let currentUser = FirebaseUserManager.shared.currentUser ?? UserManager.shared.currentUser {
                await driveManager.startDrive(for: currentUser)
                hasDriveStarted = true
                print("Camera started for user: \(currentUser.name)")
                print("Drive session started")
            }
        }
    }
    
    func setupCloseButton() {
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("End Drive", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        closeButton.layer.cornerRadius = 12
        closeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 120),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc func closeTapped() {
        print("Ending drive")
        
        // Stop motion detection
        motionDetector.stopMonitoring()
        speedTimer?.invalidate()
        speedTimer = nil
        
        // End drive session
        if hasDriveStarted {
            Task {
                await driveManager.endDrive()
                print("Drive session ended")
            }
        }
        
        captureSession.stopRunning()
        onDismiss?()
    }
    
    func setupLabel() {
        classificationLabel.isHidden = true
        classificationLabel.frame = .zero
        classificationLabel.backgroundColor = .clear
        classificationLabel.textColor = .white
        classificationLabel.textAlignment = .center
        classificationLabel.numberOfLines = 0
        view.addSubview(classificationLabel)
    }
    
    func updateClassificationLabel(with identifier: String, confidence: Float) {
        DispatchQueue.main.async {
            guard confidence > 0 else { return }
            self.alertTitleLabel.text = "Stop sign detected"
            self.alertDetailLabel.text = "Camera confirmed a stop sign ahead"
            self.confidenceLabel.text = "Confidence \(Int(confidence * 100))%"
        }
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1280x720
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        // Configure focus for distant objects
        do {
            try captureDevice.lockForConfiguration()
            if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                captureDevice.focusMode = .continuousAutoFocus
            }
            if captureDevice.isAutoFocusRangeRestrictionSupported {
                captureDevice.autoFocusRangeRestriction = .far
            }
            captureDevice.unlockForConfiguration()
        } catch {
            print("Could not configure camera:", error)
        }
        
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: visionQueue)
        captureSession.addOutput(dataOutput)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func setupDashboard() {
        setupLabel()
        
        dashboardOverlay.translatesAutoresizingMaskIntoConstraints = false
        dashboardOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        view.addSubview(dashboardOverlay)
        
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.text = "0"
        speedLabel.textColor = .white
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 62, weight: .semibold)
        speedLabel.textAlignment = .center
        
        speedCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        speedCaptionLabel.text = "mph"
        speedCaptionLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        speedCaptionLabel.font = .systemFont(ofSize: 15, weight: .medium)
        speedCaptionLabel.textAlignment = .center
        
        driveStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        driveStatusLabel.text = "Camera detection active"
        driveStatusLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        driveStatusLabel.font = .systemFont(ofSize: 15, weight: .medium)
        driveStatusLabel.textAlignment = .center
        
        alertTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        alertTitleLabel.text = "Drive ready"
        alertTitleLabel.textColor = .white
        alertTitleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        alertTitleLabel.textAlignment = .center
        alertTitleLabel.numberOfLines = 1
        alertTitleLabel.adjustsFontSizeToFitWidth = true
        alertTitleLabel.minimumScaleFactor = 0.75
        
        alertDetailLabel.translatesAutoresizingMaskIntoConstraints = false
        alertDetailLabel.text = "Detected signs will be announced"
        alertDetailLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        alertDetailLabel.font = .systemFont(ofSize: 15, weight: .regular)
        alertDetailLabel.textAlignment = .center
        alertDetailLabel.numberOfLines = 2
        
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        confidenceLabel.text = "Live mode"
        confidenceLabel.textColor = UIColor.white.withAlphaComponent(0.62)
        confidenceLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        confidenceLabel.textAlignment = .center
        
        let speedStack = UIStackView(arrangedSubviews: [speedLabel, speedCaptionLabel])
        speedStack.translatesAutoresizingMaskIntoConstraints = false
        speedStack.axis = .vertical
        speedStack.spacing = -6
        speedStack.alignment = .center
        
        let alertStack = UIStackView(arrangedSubviews: [alertTitleLabel, alertDetailLabel, confidenceLabel])
        alertStack.translatesAutoresizingMaskIntoConstraints = false
        alertStack.axis = .vertical
        alertStack.spacing = 7
        alertStack.alignment = .fill
        
        dashboardOverlay.addSubview(speedStack)
        dashboardOverlay.addSubview(alertStack)
        dashboardOverlay.addSubview(driveStatusLabel)
        
        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("End Drive", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        closeButton.layer.cornerRadius = 8
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 112),
            closeButton.heightAnchor.constraint(equalToConstant: 42),
            
            dashboardOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dashboardOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dashboardOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dashboardOverlay.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.32),
            
            speedStack.leadingAnchor.constraint(equalTo: dashboardOverlay.leadingAnchor, constant: 28),
            speedStack.centerYAnchor.constraint(equalTo: dashboardOverlay.centerYAnchor, constant: -4),
            speedStack.widthAnchor.constraint(equalToConstant: 118),
            
            alertStack.leadingAnchor.constraint(equalTo: speedStack.trailingAnchor, constant: 18),
            alertStack.trailingAnchor.constraint(equalTo: dashboardOverlay.trailingAnchor, constant: -24),
            alertStack.centerYAnchor.constraint(equalTo: dashboardOverlay.centerYAnchor, constant: -8),
            
            driveStatusLabel.leadingAnchor.constraint(equalTo: dashboardOverlay.leadingAnchor, constant: 24),
            driveStatusLabel.trailingAnchor.constraint(equalTo: dashboardOverlay.trailingAnchor, constant: -24),
            driveStatusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }
    
    private func startDashboardUpdates() {
        speedTimer?.invalidate()
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshDrivingStatus()
        }
        refreshDrivingStatus()
    }
    
    private func refreshDrivingStatus() {
        let mph = max(0, motionDetector.currentSpeed * 2.23694)
        speedLabel.text = "\(Int(mph.rounded()))"
        driveStatusLabel.text = motionDetector.isMoving ? "Moving - scanning ahead" : "Stopped - checking full stop"
    }
    
    // MARK: - Video Capture Delegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }
        guard Date().timeIntervalSince(lastFrameProcessedAt) >= frameProcessingInterval else { return }
        guard let model = visionModel else { return }
        
        isProcessingFrame = true
        lastFrameProcessedAt = Date()
        defer { isProcessingFrame = false }
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] (finishedReq, err) in
            guard let self = self else { return }
            
            if let error = err {
                self.updateClassificationLabel(with: "Error: \(error.localizedDescription)", confidence: 0)
                _ = self.stability.update(present: false)
                return
            }
            
            if let results = finishedReq.results as? [VNRecognizedObjectObservation], results.count > 0 {
                if let topLabel = results.first?.labels.first {
                    print("Detected label: '\(topLabel.identifier)'")
                }
                
                if let stop = results.first(where: { obs in
                    guard let lbl = obs.labels.first else { return false }
                    let idNorm = lbl.identifier.lowercased().replacingOccurrences(of: "_", with: " ")
                    let hasLabel = idNorm.contains("3")
                    
                    // NEW: Filter by bounding box size to reduce false positives
                    let bbox = obs.boundingBox
                    let boxWidth = bbox.width
                    let boxHeight = bbox.height
                    let boxArea = boxWidth * boxHeight
                    
                    // Stop signs should be:
                    // - Not too small (> 2% of frame)
                    // - Not too large (< 80% of frame)
                    // - Roughly square (aspect ratio between 0.7 and 1.4)
                    let minArea: CGFloat = 0.02  // 2% of frame
                    let maxArea: CGFloat = 0.80  // 80% of frame
                    let aspectRatio = boxHeight / boxWidth
                    let minAspectRatio: CGFloat = 0.7
                    let maxAspectRatio: CGFloat = 1.4
                    
                    let sizeValid = boxArea > minArea && boxArea < maxArea
                    let aspectValid = aspectRatio > minAspectRatio && aspectRatio < maxAspectRatio
                    
                    return hasLabel && sizeValid && aspectValid
                }) {
                    print("STOP SIGN MATCHED!")
                    
                    if let lbl = stop.labels.first {
                        let conf = max(stop.confidence, lbl.confidence)
                        self.updateClassificationLabel(with: lbl.identifier, confidence: conf)
                        
                        // Pass bounding box to stability gate for spatial + temporal check
                        let isStable = self.stability.update(present: true)
                        
                        guard isStable else {
                            print("Not stable yet; need consistent detection over time")
                            return
                        }
                        print("Stability passed! (consistent detection achieved)")
                        
                        let detected = DetectedObject(
                            bbox: stop.boundingBox,
                            confidence: conf,
                            label: "3",
                            timestamp: Date()
                        )
                        
                        if self.deduper.isNewObject(detected, label: "stop_sign", minConfidence: self.minConfidence) {
                            print("ANNOUNCING: Stop sign ahead")
                            self.announcer.say("Stop sign ahead")
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.warning)
                            
                            // NEW: Check if vehicle stopped and log event
                            self.motionDetector.checkIfStoppedAtStopSign { didStop, duration in
                                print("Stop check: didStop=\(didStop), duration=\(duration ?? 0)s")
                                
                                Task {
                                    await self.driveManager.addStopSignEvent(
                                        didStop: didStop,
                                        stopDuration: duration,
                                        confidence: conf,
                                        location: self.motionDetector.currentLocation
                                    )
                                    
                                    // Provide feedback
                                    DispatchQueue.main.async {
                                        if didStop {
                                            self.announcer.say("Good stop")
                                        } else {
                                            self.announcer.say("Rolling stop detected")
                                        }
                                    }
                                }
                            }
                        } else {
                            print("Deduper rejected (duplicate or low confidence)")
                        }
                    }
                } else {
                    _ = self.stability.update(present: false)
                }
                
            } else {
                self.updateClassificationLabel(with: "No results", confidence: 0)
                _ = self.stability.update(present: false)
            }
        }
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
}
