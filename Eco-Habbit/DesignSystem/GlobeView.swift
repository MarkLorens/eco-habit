import SwiftUI

struct GlobeView: View {
    enum Art {
        case globe
        case homepage
    }

    var stage: Int = 0
    var art: Art = .globe

    private var assetName: String {
        let stage = min(max(stage, 0), GlobeView.lastStage)
        switch art {
        case .globe: return "globe-static-stage-\(stage)"
        case .homepage: return "stage-\(stage)-homepage"
        }
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
