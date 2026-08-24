import SwiftUI

private enum GlobeArt {
    struct Geometry {
        let widthFraction: CGFloat
        let centreX: CGFloat
        let centreY: CGFloat
        var fillScale: CGFloat { 1 / widthFraction }
        var nudgeX: CGFloat { (0.5 - centreX) * fillScale }
        var nudgeY: CGFloat { (0.5 - centreY) * fillScale }
    }
    static func geometry(forStage stage: Int) -> Geometry {
        stage == 0
            ? Geometry(widthFraction: 0.8003, centreX: 0.4814, centreY: 0.4866)
            : Geometry(widthFraction: 0.7661, centreX: 0.4927, centreY: 0.5305)
    }
}

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showingStageInfo = false

    @State private var isGlobeFocused = false

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let centringLift = max(0, (proxy.size.height - side) / 2)

            VStack(alignment: .leading, spacing: 0) {
                header

                if !isGlobeFocused {
                    RecommendationDeck()
                        .padding(.top, Tokens.Spacing.goodLord)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                globe(side: side)
                    .padding(.bottom, isGlobeFocused ? centringLift : 0)
                    .offset(y: isGlobeFocused ? 0 : side * 0.35)
                    .scaleEffect(isGlobeFocused ? 0.75 : 1.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        HStack(alignment: .top){
            VStack(alignment: .leading, spacing: Tokens.Spacing.xs) {
                Text("Hi, \(app.firstName)!")
                    .textStyle(Tokens.Typography.hero)
                    .foregroundStyle(Tokens.Semantic.text)

                Text("Let's make today better")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
            Spacer()

            VStack{
                Image(systemName: "flame.fill")
                    .textStyle(Tokens.Typography.hero)
                    .foregroundStyle(Tokens.Palette.orange)

                Text("\(app.streakDays)")
                    .textStyle(Tokens.Typography.hero)
                    .foregroundStyle(Tokens.Palette.orange)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(app.streakDays) day streak")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Tokens.Spacing.xxl)
        .padding(.vertical, Tokens.Spacing.lg)
    }
    private func globe(side: CGFloat) -> some View {
        let art = GlobeArt.geometry(forStage: app.globeStage)
        let canvas = side * art.fillScale
        return GlobeView(stage: app.globeStage, art: isGlobeFocused ? .globe : .homepage)
            .frame(width: canvas, height: canvas)
            .offset(x: side * art.nudgeX, y: side * art.nudgeY)
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.35)) { isGlobeFocused.toggle() }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let verticalMovement = value.translation.height

                        if verticalMovement < -30 {
                            // Swiped up
                            withAnimation(.snappy(duration: 0.35)) {
                                isGlobeFocused = true
                            }
                        } else if verticalMovement > 30 {
                            // Swiped down
                            withAnimation(.snappy(duration: 0.35)) {
                                isGlobeFocused = false
                            }
                        }
                    }
            )
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Your Earth, stage \(app.globeStage + 1) of \(GlobeView.lastStage + 1)")
        .accessibilityHint(isGlobeFocused
                           ? "Double tap to show your recommended actions"
                           : "Double tap for a closer look")
    }
}

#if DEBUG
#Preview {
    MainTabView().environmentObject(AppState.preview)
}
#endif
