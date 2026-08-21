import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var showingStageInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                RecommendationDeck()
                    .padding(.top, Tokens.Spacing.xl)
                globe
            }
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

    private var globe: some View {
        GlobeView(stage: app.globeStage)
            .padding(.top, Tokens.Spacing.goodLord)
    }
}

#if DEBUG
#Preview {
    MainTabView().environmentObject(AppState.preview)
}
#endif
