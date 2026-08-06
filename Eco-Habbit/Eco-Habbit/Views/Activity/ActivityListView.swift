import SwiftUI

struct ActivityListView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sustainability Activity")
                        .font(Theme.F.heading(24))
                        .foregroundStyle(Theme.C.text)

                    Text("One credit per activity per day — from here or from the camera.")
                        .font(Theme.F.body(13.5))
                        .foregroundStyle(Theme.C.neutral600)
                        .padding(.top, 6)

                    VStack(spacing: 10) {
                        ForEach(sortedCategories) { category in
                            NavigationLink(value: category) {
                                CategoryRow(
                                    category: category,
                                    done: app.doneCount(in: category),
                                    total: MockData.activities(in: category).count,
                                    isFavourite: app.favouriteCategories.contains(category)
                                )
                            }
                            .buttonStyle(PlainPressStyle())
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .tabContentInsets()
            }
            .background(Theme.C.bg)
            .navigationDestination(for: ActivityCategory.self) { category in
                CategoryDetailView(category: category)
            }
        }
        .tint(Theme.C.accent)
    }

    /// Favourites float to the top — that's the point of picking them in onboarding.
    private var sortedCategories: [ActivityCategory] {
        ActivityCategory.allCases.sorted { lhs, rhs in
            let l = app.favouriteCategories.contains(lhs)
            let r = app.favouriteCategories.contains(rhs)
            if l != r { return l }
            return lhs.rawValue < rhs.rawValue
        }
    }
}

private struct CategoryRow: View {
    let category: ActivityCategory
    let done: Int
    let total: Int
    let isFavourite: Bool

    var body: some View {
        HStack(spacing: 14) {
            CategoryIconView(glyph: category.glyph, size: 22, color: Theme.C.accent2_700)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.C.accent2_100))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.name)
                        .font(Theme.F.body(15, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                    if isFavourite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.C.accent400)
                    }
                }
                Text("\(done)/\(total) done today")
                    .font(Theme.F.body(12.5))
                    .foregroundStyle(Theme.C.neutral600)
            }

            Spacer()
            ChevronRight()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.R.card)
                .fill(Theme.C.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.R.card)
                        .stroke(Theme.C.neutral200, lineWidth: 1)
                )
        )
        .elevation(Theme.E.sm)
    }
}
