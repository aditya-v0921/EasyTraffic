import SwiftUI
import AVKit
import Vision
import AVFoundation

// UIViewController for Camera
class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var classificationLabel = UILabel()

    // NEW: helpers & config (does not change your detection logic)
    private let announcer = Announcer.shared
    private let deduper = Deduper()
    private let stability = StabilityGate()
    private let minConfidence: Float = 0.65

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupLabel()
        
        // TEST: Speak after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            print("🧪 Testing speech...")
            self.announcer.say("Testing speech synthesis")
        }
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
            captureSession.sessionPreset = .photo
            
            guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }

            guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
            captureSession.addInput(input)

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            let dataOutput = AVCaptureVideoDataOutput()
            dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            captureSession.addOutput(dataOutput)

            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                DispatchQueue.main.async {
                    // Update your UI if needed
                }
            }
        }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        guard let model = try? VNCoreMLModel(for: SS1().model) else { return }
        
        let request = VNCoreMLRequest(model: model) { [weak self] (finishedReq, err) in
            guard let self = self else { return }
            
            // Keep your original print
            print(finishedReq.results?.first?.confidence)
            
            if let error = err {
                self.updateClassificationLabel(with: "Error: \(error.localizedDescription)", confidence: 0)
                _ = self.stability.update(present: false)
                return
            }

            if let results = finishedReq.results as? [VNRecognizedObjectObservation], results.count > 0 {
                // Print what label we got
                if let topLabel = results.first?.labels.first {
                    print("🏷️ Detected label: '\(topLabel.identifier)'")
                }
                
                // Keep your original label update
                if let topLabel = results.first?.labels.first, let confidence = results.first?.confidence {
                    self.updateClassificationLabel(with: topLabel.identifier, confidence: confidence)
                }

                // Look for stop sign
                if let stop = results.first(where: { obs in
                    guard let lbl = obs.labels.first else { return false }
                    let idNorm = lbl.identifier.lowercased().replacingOccurrences(of: "_", with: " ")
                    let hasLabel = idNorm.contains("3")
                    //let hasSign = idNorm.contains("sign")
                    print("🔎 Checking '\(idNorm)': hasStop=\(hasLabel)")
                    return hasLabel //&& hasSign
                }) {
                    print("🛑 STOP SIGN MATCHED!")
                    
                    if let lbl = stop.labels.first {
                        let conf = max(stop.confidence, lbl.confidence)
                        
                        guard self.stability.update(present: true) else {
                            print("❌ Not stable yet (need 2 frames)")
                            return
                        }
                        print("✅ Stability passed!")
                        
                        let detected = DetectedObject(
                            bbox: stop.boundingBox,
                            confidence: conf,
                            label: "3",
                            timestamp: Date()
                        )
                        
                        if self.deduper.isNewObject(detected, label: "stop_sign", minConfidence: self.minConfidence) {
                            print("✅✅ ANNOUNCING: Stop sign ahead")
                            self.announcer.say("Stop sign ahead")
                            let gen = UINotificationFeedbackGenerator()
                            gen.notificationOccurred(.warning)
                        } else {
                            print("❌ Deduper rejected (duplicate or low confidence)")
                        }
                    }
                } else {
                    print("❌ No stop sign found in this frame")
                    _ = self.stability.update(present: false)
                }

            } else {
                self.updateClassificationLabel(with: "No results", confidence: 0)
                _ = self.stability.update(present: false)
            }
        }
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
    final class Announcer: NSObject, AVSpeechSynthesizerDelegate {
        static let shared = Announcer()
        private let synth = AVSpeechSynthesizer()
        private var lastSpokenAt: Date = .distantPast
        var minSpeakInterval: TimeInterval = 6.0

        private override init() {
            super.init()
            synth.delegate = self
            configureAudioSession()
        }

        private func configureAudioSession() {
            let session = AVAudioSession.sharedInstance()
            do {
                // Simpler: just playback with ducking
                try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
                try session.setActive(true, options: [])
                print("✅ Audio session configured successfully")
            } catch {
                print("⚠️ Audio session error:", error)
            }
            
        }
        
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
            print("✅ Speech started:", utterance.speechString)
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            print("✅ Speech finished:", utterance.speechString)
        }

        func say(_ text: String) {
            guard Date().timeIntervalSince(lastSpokenAt) > minSpeakInterval else { return }
            let u = AVSpeechUtterance(string: text)
            u.voice = AVSpeechSynthesisVoice(language: "en-US")
            u.rate = AVSpeechUtteranceDefaultSpeechRate
            synth.speak(u)
            lastSpokenAt = Date()
            print("🔊 Speaking:", text)
        }
    }


    // MARK: - Detection models
    struct DetectedObject {
        let bbox: CGRect // normalized [0,1] in image space
        let confidence: Float
        let label: String
        let timestamp: Date
    }

    // MARK: - Simple stability (require N consecutive frames with presence)
    final class StabilityGate {
        private var hits = 0
        var needed = 2
        func update(present: Bool) -> Bool {
            hits = present ? hits + 1 : 0
            return hits >= needed
        }
    }

    // MARK: - De-dup based on IoU + short memory
    final class Deduper {
        private var lastAnnounced: DetectedObject?
        private func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
            let inter = a.intersection(b)
            guard !inter.isNull else { return 0 }
            let interArea = inter.width * inter.height
            let unionArea = a.width * a.height + b.width * b.height - interArea
            return unionArea > 0 ? interArea / unionArea : 0
        }
        func isNewObject(_ obj: DetectedObject,
                         label: String,
                         minConfidence: Float = 0.65,
                         maxSpatialOverlapForNew: CGFloat = 0.35,
                         forgetAfter: TimeInterval = 8.0) -> Bool {
            guard obj.confidence >= minConfidence else { return false }
            if let last = lastAnnounced,
               Date().timeIntervalSince(last.timestamp) > forgetAfter {
                lastAnnounced = nil
            }
            guard let last = lastAnnounced, last.label == label else {
                lastAnnounced = obj
                return true
            }
            // If it's basically the same box, don't announce again
            if iou(last.bbox, obj.bbox) > maxSpatialOverlapForNew {
                return false
            }
            lastAnnounced = obj
            return true
        }
    }
}
