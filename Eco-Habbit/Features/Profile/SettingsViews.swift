import SwiftUI

struct FavouriteCategoriesView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selection: Set<HabitCategory> = []

    var body: some View {
        SettingsScaffold(
            title: "Favorite categories",
            subtitle: "Pick 2–3. These float to the top of the activity list."
        ) {
            VStack(spacing: 10) {
                ForEach(HabitCategory.allCases, id: \.self) { category in
                    let isOn = selection.contains(category)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { toggle(category) }
                    } label: {
                        HStack(spacing: 14) {
                            CategoryIconView(
                                glyph: category.icon,
                                size: 22,
                                color: isOn ? Tokens.Palette.orange : Tokens.Semantic.footnote
                            )
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isOn ? Tokens.Palette.greenFaint : Tokens.Semantic.buttonTintDefault)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .textStyle(Tokens.Typography.body)
                                    .foregroundStyle(Tokens.Semantic.text)
                                Text(category.caption)
                                    .textStyle(Tokens.Typography.footnote)
                                    .foregroundStyle(Tokens.Semantic.footnote)
                            }

                            Spacer()

                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isOn ? Tokens.Palette.green : Tokens.Semantic.statIcon)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                                .fill(Tokens.Semantic.buttonTintDefault)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Tokens.Radius.basicCards)
                                        .stroke(isOn ? Tokens.Palette.green : Tokens.Semantic.statIcon.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainPressStyle())
                }

                Text("\(selection.count) of 3 selected")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
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

    private func toggle(_ category: HabitCategory) {
        if selection.contains(category) {
            selection.remove(category)
        } else if selection.count < 3 {
            selection.insert(category)
        }
    }
}

struct NotificationSettingsView: View {
    @EnvironmentObject private var app: AppState

    @State private var dailyReminder = true
    @State private var streakAlerts = true

    var body: some View {
        SettingsScaffold(
            title: "Notifications",
            subtitle: "UI only at this stage."
        ) {
            EHCard(padding: 4) {
                VStack(spacing: 0) {
                    toggleRow("All notifications", isOn: Binding(
                        get: { app.notificationsEnabled },
                        set: { app.setNotifications($0) }
                    ))
                    toggleRow("Daily reminder", isOn: $dailyReminder)
                        .disabled(!app.notificationsEnabled)
                    toggleRow("Streak at risk", isOn: $streakAlerts, showsDivider: false)
                        .disabled(!app.notificationsEnabled)
                }
            }
            .opacity(app.notificationsEnabled ? 1 : 0.75)
        }
    }

    private func toggleRow(
        _ title: String,
        isOn: Binding<Bool>,
        showsDivider: Bool = true
    ) -> some View {
        SettingsRow(title: title, showsDivider: showsDivider) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Tokens.Palette.green)
        }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        SettingsScaffold(
            title: "Privacy",
            subtitle: "What is kept, where it is kept, and what leaves this device."
        ) {
            VStack(spacing: 14) {
                EHCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("On this device", systemImage: "internaldrive")
                            .textStyle(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Semantic.text)
                        Text("\(app.totalActionsLogged) logged actions, and \(app.savedEvidence.count) photos taken through the camera.")
                    }
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                }

                // This card used to say "No photos, ever — nothing is written to disk",
                // which stopped being true the moment camera logs started keeping their
                // frame. A privacy screen that is out of date is worse than none.
                EHCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Photos stay here", systemImage: "photo.on.rectangle")
                            .textStyle(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Semantic.text)
                        Text("A photo you log with is saved on this device only, and never uploaded. Deleting the action deletes its photo, and \u{201C}Reset local data\u{201D} removes every one.")
                    }
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                }

                EHCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Synced to your account", systemImage: "icloud")
                            .textStyle(Tokens.Typography.body)
                            .foregroundStyle(Tokens.Semantic.text)
                        Text("Signed in, your points, streak, action history and badges are backed up so they survive a reinstall. Only you can read them. Delete your account to remove them.")
                    }
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                }

                // Camera access is requested by CameraService the first time the camera
                // opens, and revoked from iOS Settings. A mirror toggle here would only
                // ever be a lie about what the system actually permits.
                Text("Camera access is asked for when you first open the camera, and lives in iOS Settings.")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

}

struct ActivityHistoryView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        SettingsScaffold(
            title: "Activity history",
            subtitle: app.history.isEmpty
                ? "Nothing logged yet."
                : "\(app.totalActionsLogged) entries logged."
        ) {
            if app.history.isEmpty {
                EHCard(padding: 18) {
                    Text("Log your first action and it shows up here.")
                        .textStyle(Tokens.Typography.footnote)
                        .foregroundStyle(Tokens.Semantic.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(groupedHistory, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Self.dayLabel(group.day))
                                .textStyle(Tokens.Typography.footnote)
                                .tracking(0.5)
                                .foregroundStyle(Tokens.Semantic.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)

                            EHCard(padding: 4) {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                        HistoryRow(entry: entry)
                                        if index < group.entries.count - 1 {
                                            Rectangle()
                                                .fill(Tokens.Semantic.statIcon.opacity(0.3))
                                                .frame(height: 1)
                                                .padding(.horizontal, 12)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedHistory: [(day: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: app.history) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private static func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "TODAY" }
        if Calendar.current.isDateInYesterday(date) { return "YESTERDAY" }
        return date.formatted(.dateTime.weekday(.wide).month().day()).uppercased()
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(glyph: entry.category.icon, size: 18, color: Tokens.Palette.greenDark)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Tokens.Palette.greenFaint))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.text)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                    if entry.source == .visualSearch {
                        Label("Camera", systemImage: "camera.fill")
                    }
                }
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
            }

            Spacer()

            EHTag(text: "+\(entry.points)", style: .accent2)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
}

struct SettingsScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    CircleIconButton(systemName: "chevron.left") { dismiss() }
                    Text(title)
                        .textStyle(Tokens.Typography.title)
                        .foregroundStyle(Tokens.Semantic.text)
                    Spacer()
                }

                Text(subtitle)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                VStack(spacing: 0) { content }
                    .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .tabContentInsets()
        }
        .background(Tokens.Palette.white)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}
