import SwiftUI
import AVKit
import Vision
import AVFoundation

// UIViewController for Camera
class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var classificationLabel = UILabel()

    override func viewDidLoad() {
           super.viewDidLoad()
           setupCamera()
           setupLabel()
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
            print(finishedReq.results?.first?.confidence)
            if let error = err {
                self.updateClassificationLabel(with: "Error: \(error.localizedDescription)", confidence: 0)
                return
            }

            if let results = finishedReq.results as? [VNRecognizedObjectObservation], results.count > 0 {
                if let topLabel = results.first?.labels.first, let confidence = results.first?.confidence {
                    self.updateClassificationLabel(with: topLabel.identifier, confidence: confidence)
                }

            } else {
                self.updateClassificationLabel(with: "No results", confidence: 0) // Clear the label if no objects are detected
            }
        }
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }


    }
