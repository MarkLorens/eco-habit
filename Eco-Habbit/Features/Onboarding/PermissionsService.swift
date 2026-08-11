import AVFoundation
import Combine

@MainActor
final class PermissionsService: NSObject, ObservableObject {
    @Published private(set) var cameraGranted = false

    override init() {
        super.init()
        cameraGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
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
}
