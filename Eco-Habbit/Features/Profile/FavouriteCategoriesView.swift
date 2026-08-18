import SwiftUI

/// Mark's screen, ported verbatim — only `HabitCategory` became `Category`.
///
/// `Category.title`, `.caption` and `.icon` were added to `Category+Presentation`
/// so this file did not have to be rewritten line by line; the strings they
/// return are the ones his version showed, character for character.

struct FavouriteCategoriesView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<Category> = []

    var body: some View {
        SettingsScaffold(
            title: "Favorite categories",
            subtitle: "Pick 2–3. These float to the top of the activity list."
        ) {
            VStack(spacing: 10) {
                ForEach(Category.allCases, id: \.self) { category in
                    let isOn = selection.contains(category)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { toggle(category) }
                    } label: {
                        HStack(spacing: 14) {
                            CategoryIconView(
                                glyph: category.icon,
                                size: 22,
                                color: isOn ? Theme.C.accent600 : Theme.C.neutral600
                            )
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isOn ? Theme.C.accent100 : Theme.C.neutral100)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(Theme.F.body(15, weight: .bold))
                                    .foregroundStyle(Theme.C.text)
                                Text(category.caption)
                                    .font(Theme.F.body(12.5))
                                    .foregroundStyle(Theme.C.neutral600)
                            }

                            Spacer()

                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isOn ? Theme.C.accent500 : Theme.C.neutral300)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.R.card)
                                .fill(Theme.C.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.R.card)
                                        .stroke(isOn ? Theme.C.accent500 : Theme.C.neutral200, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainPressStyle())
                }

                Text("\(selection.count) of 3 selected")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
                    .padding(.top, 6)

                Button("Save") {
                    app.updateFavourites(selection)
                    app.toast = Toast(kind: .success, message: "Favorites updated.")
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(height: 50))
                .disabled(selection.count < 2)
                .padding(.top, 8)
            }
        }
        .onAppear { selection = app.favouriteCategories }
    }

    private func toggle(_ category: Category) {
        if selection.contains(category) {
            selection.remove(category)
        } else if selection.count < 3 {
            selection.insert(category)
        }
    }
}
