import AVFoundation
import CoreLocation
import Combine

/// Thin wrapper over the two native permission prompts the onboarding asks for.
/// Both are optional — declining never blocks the flow.
@MainActor
final class PermissionsService: NSObject, ObservableObject {
    @Published private(set) var cameraGranted = false
    @Published private(set) var locationGranted = false

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        locationGranted = Self.isAuthorized(locationManager.authorizationStatus)
    }

    func requestCamera() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraGranted = true
        case .notDetermined:
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            cameraGranted = false
        }
        return cameraGranted
    }

    func requestLocation() async -> Bool {
        let status = locationManager.authorizationStatus
        guard status == .notDetermined else {
            locationGranted = Self.isAuthorized(status)
            return locationGranted
        }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private static func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

extension PermissionsService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard status != .notDetermined else { return }
            locationGranted = Self.isAuthorized(status)
            locationContinuation?.resume(returning: locationGranted)
            locationContinuation = nil
        }
    }
}
