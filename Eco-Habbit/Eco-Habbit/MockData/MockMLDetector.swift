import UIKit

/// Stand-in for the CoreML model that will eventually classify the photo.
///
/// It picks at random from the activities flagged `isCameraDetectable`, biased toward
/// the user's favourite categories so the demo feels personalised, and reports a
/// plausible confidence. Swapping this for a real `VNCoreMLRequest` later means
/// replacing the body of `detect(in:favouring:)` and nothing else.
nonisolated enum MockMLDetector {

    struct Result {
        let activity: Activity
        let confidence: Double
    }

    /// Roughly matches the design's 1.3s "Analyzing your action..." beat.
    static let analysisDuration: Duration = .milliseconds(1_300)

    static func detect(in image: UIImage?, favouring favourites: Set<ActivityCategory>) -> Result {
        _ = image  // the real model will read pixels here

        let pool = MockData.cameraDetectable
        let preferred = pool.filter { favourites.contains($0.category) }

        // 70/30 split toward the user's chosen categories when we have any.
        let candidates = (!preferred.isEmpty && Double.random(in: 0...1) < 0.7) ? preferred : pool
        let picked = candidates.randomElement() ?? pool[0]

        return Result(activity: picked, confidence: Double.random(in: 0.71...0.96))
    }

    /// Alternatives offered in the "not the right category?" correction strip —
    /// one detectable activity per category other than the detected one.
    static func corrections(excluding detected: Activity) -> [Activity] {
        ActivityCategory.allCases.compactMap { category in
            guard category != detected.category else { return nil }
            return MockData.cameraDetectable.first { $0.category == category }
        }
    }
}
