import SwiftUI

/// Tap-through story recap, built from whatever the user has actually logged.
struct MonthlyWrapView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var slideIndex = 0

    private struct Slide {
        let kicker: String
        let big: String
        let sub: String
    }

    private var slides: [Slide] {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        let entries = app.history.filter { $0.date >= monthStart }
        let monthName = Date().formatted(.dateTime.month(.wide))

        let topCategory = Dictionary(grouping: entries, by: \.categoryRaw)
            .max { $0.value.count < $1.value.count }

        let topName = topCategory
            .flatMap { ActivityCategory(rawValue: $0.key)?.name } ?? "Nothing yet"
        let topCount = topCategory?.value.count ?? 0

        return [
            Slide(
                kicker: "Your \(monthName) Wrap",
                big: "\(entries.count)",
                sub: entries.isEmpty
                    ? "actions logged — there's still time"
                    : "sustainable actions logged"
            ),
            Slide(
                kicker: "Top category",
                big: topName,
                sub: topCount == 0 ? "Pick a category and get going" : "\(topCount) actions this month"
            ),
            Slide(
                kicker: "Longest streak",
                big: "\(max(app.streakDays, app.data.longestStreak))",
                sub: "days in a row without missing a beat"
            ),
            Slide(
                kicker: "The Earth thanks you",
                big: "\(Int(app.globeHealth))%",
                sub: "globe health at \(app.stage.name.lowercased()) stage"
            ),
        ]
    }

    private var isLast: Bool { slideIndex == slides.count - 1 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.C.accent700, Theme.C.accent2_700],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 6) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Capsule()
                                .fill(index <= slideIndex ? .white : .white.opacity(0.35))
                                .frame(width: 26, height: 4)
                        }
                    }
                    Spacer()
                    CircleIconButton(
                        systemName: "xmark",
                        size: 28,
                        background: .white.opacity(0.2),
                        foreground: .white
                    ) { dismiss() }
                }
                .padding(.top, 12)

                Spacer()

                let slide = slides[slideIndex]
                VStack(spacing: 10) {
                    Text(slide.kicker)
                        .font(Theme.F.body(14))
                        .foregroundStyle(.white.opacity(0.8))

                    Text(slide.big)
                        .font(Theme.F.heading(slide.big.count > 8 ? 34 : 52))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)

                    Text(slide.sub)
                        .font(Theme.F.body(15))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 265)
                }
                .id(slideIndex)
                .transition(.opacity)

                Spacer()

                if isLast {
                    HStack(spacing: 10) {
                        Button("Close") { dismiss() }
                            .buttonStyle(SecondaryButtonStyle(height: 48, fontSize: 15))
                            .foregroundStyle(.white)

                        ShareLink(item: shareText) {
                            Text("Share")
                                .font(Theme.F.heading(15))
                                .foregroundStyle(Theme.C.accent700)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Capsule().fill(.white))
                        }
                    }
                } else {
                    Text("Tap to continue")
                        .font(Theme.F.body(13))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(height: 48)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isLast else { return }
            withAnimation(.easeInOut(duration: 0.25)) { slideIndex += 1 }
        }
    }

    private var shareText: String {
        "My Eco Habit wrap: \(app.totalActionsLogged) sustainable actions, \(app.earthPoints) Earth Points, globe at \(Int(app.globeHealth))%."
    }
}
