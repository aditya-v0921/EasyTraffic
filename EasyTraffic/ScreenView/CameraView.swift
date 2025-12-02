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
    
    // NEW: Drive tracking and motion detection
    private let driveManager = FirebaseDriveManager.shared
    private let motionDetector = MotionDetector()
    private var hasDriveStarted = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupLabel()
        setupCloseButton()
        
        // Start motion detection
        motionDetector.startMonitoring()
        
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
        //motionDetector.stopMonitoring()
        
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
        classificationLabel.frame = CGRect(x: 0, y: view.frame.height - 100, width: view.frame.width, height: 100)
        classificationLabel.backgroundColor = .white
        classificationLabel.textColor = .black
        classificationLabel.textAlignment = .center
        classificationLabel.numberOfLines = 0
        view.addSubview(classificationLabel)
    }
    
    func updateClassificationLabel(with identifier: String, confidence: Float) {
        DispatchQueue.main.async {
            self.classificationLabel.text = "Label: Stop Sign, Confidence: \(confidence)"
        }
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1920x1080
        
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
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    // MARK: - Video Capture Delegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        guard let model = try? VNCoreMLModel(for: SS1().model) else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] (finishedReq, err) in
            guard let self = self else { return }
            
            print(finishedReq.results?.first?.confidence)
            
            if let error = err {
                self.updateClassificationLabel(with: "Error: \(error.localizedDescription)", confidence: 0)
                _ = self.stability.update(present: false)
                return
            }
            
            if let results = finishedReq.results as? [VNRecognizedObjectObservation], results.count > 0 {
                if let topLabel = results.first?.labels.first {
                    print("🏷️ Detected label: '\(topLabel.identifier)'")
                }
                
                if let topLabel = results.first?.labels.first, let confidence = results.first?.confidence {
                    self.updateClassificationLabel(with: topLabel.identifier, confidence: confidence)
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
                    
                    if hasLabel && !sizeValid {
                        print("❌ Rejected: size invalid (area: \(String(format: "%.3f", boxArea)))")
                    }
                    if hasLabel && !aspectValid {
                        print("❌ Rejected: aspect ratio invalid (\(String(format: "%.2f", aspectRatio)))")
                    }
                    
                    print("🔎 Checking '\(idNorm)': hasStop=\(hasLabel), sizeValid=\(sizeValid), aspectValid=\(aspectValid)")
                    return hasLabel && sizeValid && aspectValid
                }) {
                    print("STOP SIGN MATCHED!")
                    
                    if let lbl = stop.labels.first {
                        let conf = max(stop.confidence, lbl.confidence)
                        
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
                    print("No stop sign found in this frame")
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

