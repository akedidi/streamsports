import UIKit

extension UIDevice {
    static func vibrate() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
// Helper to force rotation
struct DeviceRotation {
    static func rotate(to orientation: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = orientation
        
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
                // Fallback attempt for forceful UI update
                UIViewController.attemptRotationToDeviceOrientation()
            }
        } else {
            if orientation == .landscapeRight {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            }
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}
