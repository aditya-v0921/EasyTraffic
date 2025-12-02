import Foundation
import CoreMotion
import CoreLocation

// FIX 1: Add ObservableObject protocol
class MotionDetector: NSObject, ObservableObject {
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    
    @Published var isMoving: Bool = false
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var currentSpeed: Double = 0 // m/s
    
    private var stopDetectionStartTime: Date?
    private let isStoppedThreshold: Double = 0.5 // m/s
    private let requiredStopDuration: TimeInterval = 2.0
    
    // Helper to check if currently stationary based on last known data
    var didFullStop: Bool {
        guard let startTime = stopDetectionStartTime else { return false }
        return Date().timeIntervalSince(startTime) >= requiredStopDuration
    }
    
    var stopDuration: TimeInterval? {
        guard let startTime = stopDetectionStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }
    
    override init() {
        super.init() // Good practice to call super.init() first
        setupLocationManager()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        // OPTIMIZATION: kCLLocationAccuracyBestForNavigation is better for speed,
        // but Best is acceptable.
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Start/Stop Monitoring
    
    func startMonitoring() {
        locationManager.startUpdatingLocation()
        
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                guard let self = self, let data = data else { return }
                self.processAccelerometerData(data)
            }
        }
        print("Motion monitoring started")
    }
    
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        motionManager.stopAccelerometerUpdates()
        print("Motion monitoring stopped")
    }
    
    // MARK: - Process Motion Data
    
    private func processAccelerometerData(_ data: CMAccelerometerData) {
        // Use accelerometer to ASSIST determination, not override it completely
        // if GPS says we are moving fast.
        
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z
        let magnitude = sqrt(x * x + y * y + z * z)
        
        // Deviation from 1.0 (gravity)
        let isLikelyMoving = abs(magnitude - 1.0) > 0.1
        
        updateMovementStatus(accelerometerSuggestsMovement: isLikelyMoving)
    }
    
    private func updateMovementStatus(accelerometerSuggestsMovement: Bool) {
        // FIX 2: Logic Overhaul
        
        let isGpsStopped = currentSpeed < isStoppedThreshold
        
        var isStopped: Bool
        
        if currentSpeed > 2.0 {
            // If GPS says we are going > 4.5 mph, we are definitely moving.
            // Ignore accelerometer (avoids "Smooth Ride" bug).
            isStopped = false
        } else {
            // If GPS speed is low (or 0), we use AND logic.
            // We are stopped if GPS is low AND accelerometer is calm.
            // This prevents GPS drift from triggering "Moving" when we are actually stopped.
            isStopped = isGpsStopped && !accelerometerSuggestsMovement
        }
        
        handleStateChange(isStopped: isStopped)
    }
    
    // Refactored state change logic for clarity
    private func handleStateChange(isStopped: Bool) {
        if isStopped {
            if isMoving {
                // Transition from Moving -> Stopped
                isMoving = false
                stopDetectionStartTime = Date()
                print("Vehicle stopped")
            }
            // If already stopped, do nothing (timer keeps running)
        } else {
            if !isMoving {
                // Transition from Stopped -> Moving
                isMoving = true
                
                if let duration = stopDuration {
                    print("Stop completed - Duration: \(String(format: "%.1f", duration))s")
                }
                
                stopDetectionStartTime = nil
                print("Vehicle moving")
            } else {
                // Continuing to move, ensure timer is cleared
                 stopDetectionStartTime = nil
            }
        }
    }
    
    // MARK: - Stop Detection for Events
    
    func checkIfStoppedAtStopSign(completion: @escaping (Bool, TimeInterval?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + requiredStopDuration + 0.5) { [weak self] in
            guard let self = self else { return }
            completion(self.didFullStop, self.stopDuration)
        }
    }
    
    func reset() {
        stopDetectionStartTime = nil
        isMoving = false
        currentSpeed = 0
    }
}

// MARK: - CLLocationManagerDelegate

extension MotionDetector: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location.coordinate
            // Ensure negative speed (invalid) is treated as 0
            self.currentSpeed = max(0, location.speed)
            
            // We don't call updateMovementStatus here directly to avoid race conditions
            // with the accelerometer. Instead, we let the faster accelerometer loop
            // pick up the new speed value naturally.
            // OR: We can trigger it here, but we need to know the last accelerometer state.
            // For simplicity in this fix, we will trust the accelerometer loop to read
            // this new self.currentSpeed value on its next tick (0.1s later).
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            print("Location authorized")
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}
