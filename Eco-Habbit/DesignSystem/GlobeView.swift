import SwiftUI

struct GlobeView: View {
    var stage: Int = 0

    private var assetName: String {
        "globe-static-stage-\(min(max(stage, 0), GlobeView.lastStage))"
    }
    
    static let lastStage = 5

    var body: some View{
        Image(assetName)
            .resizable()
            .scaledToFit()
    }
}

/// One step up the globe ladder, e.g. stage 2 → 3. Drives the unlock animation,
/// whose `.lottie` files are named after the step they cover.
struct GlobeStageUp: Identifiable, Equatable {
    let from: Int
    let to: Int

    var id: Int { to }
    var lottieName: String { "stage \(from)-\(to)" }
}

#Preview {
    GlobeView()
}
