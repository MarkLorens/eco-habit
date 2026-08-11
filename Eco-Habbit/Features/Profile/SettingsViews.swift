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
                ForEach(HabitCategory.allCases) { category in
                    let isOn = selection.contains(category)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { toggle(category) }
                    } label: {
                        HStack(spacing: 14) {
                            CategoryIconView(
                                glyph: category.glyph,
                                size: 22,
                                color: isOn ? Theme.C.accent600 : Theme.C.neutral600
                            )
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isOn ? Theme.C.accent100 : Theme.C.neutral100)
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .font(Theme.F.body(15, weight: .bold))
                                    .foregroundStyle(Theme.C.text)
                                Text(category.blurb)
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
                .tint(Theme.C.accent500)
        }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        SettingsScaffold(
            title: "Privacy",
            subtitle: "Everything you log lives on this device. Nothing is uploaded anywhere."
        ) {
            VStack(spacing: 14) {
                EHCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Stored on this device", systemImage: "internaldrive")
                            .font(Theme.F.body(14, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                        Text("  \(app.totalActionsLogged) logged actions")
                    }
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral700)
                }

                EHCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No photos, ever", systemImage: "camera.metering.none")
                            .font(Theme.F.body(14, weight: .bold))
                            .foregroundStyle(Theme.C.text)
                        Text("The camera is a search tool. Frames are read in memory and discarded — nothing is written to disk, the photo library, or the network.")
                    }
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral700)
                }

                // Camera access is requested by CameraService the first time the camera
                // opens, and revoked from iOS Settings. A mirror toggle here would only
                // ever be a lie about what the system actually permits.
                Text("Camera access is asked for when you first open the camera, and lives in iOS Settings.")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)
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
                        .font(Theme.F.body(13.5))
                        .foregroundStyle(Theme.C.neutral700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(groupedHistory, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(Self.dayLabel(group.day))
                                .font(Theme.F.body(12, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Theme.C.neutral600)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 16)

                            EHCard(padding: 4) {
                                VStack(spacing: 0) {
                                    ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                        HistoryRow(entry: entry)
                                        if index < group.entries.count - 1 {
                                            Rectangle()
                                                .fill(Theme.C.neutral200)
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
            CategoryIconView(glyph: entry.category.glyph, size: 18, color: Theme.C.accent2_700)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.C.accent2_100))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(Theme.F.body(14, weight: .semibold))
                    .foregroundStyle(Theme.C.text)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                    if entry.source == .visualSearch {
                        Label("Camera", systemImage: "camera.fill")
                    }
                }
                .font(Theme.F.body(11.5))
                .foregroundStyle(Theme.C.neutral600)
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
                        .font(Theme.F.heading(20))
                        .foregroundStyle(Theme.C.text)
                    Spacer()
                }

                Text(subtitle)
                    .font(Theme.F.body(13.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)

                VStack(spacing: 0) { content }
                    .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .tabContentInsets()
        }
        .background(Theme.C.bg)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}
