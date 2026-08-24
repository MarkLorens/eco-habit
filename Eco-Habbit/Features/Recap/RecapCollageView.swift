//
//  RecapCollageView.swift
//  Eco-Habbit
//

import SwiftUI

/// A month of evidence photos, pinned over the calendar they were taken on.
///
/// Where `RecapView` counts, this one *shows*: the photos are the only record in the app
/// of what an action actually looked like, and until now nothing outside the debug menu
/// ever read them back.
///
/// **Only a fraction of logs have a photo.** One exists where the log came through the
/// camera and this is the device that took it — logs merge both ways from Firestore,
/// photos never do (see `EvidenceStore`). So the wall is always sparser than the tally
/// on the screen behind it, and after a reinstall it is legitimately empty against a
/// full history. That is why the month pager only ever offers months that *have*
/// photos, and why the empty state explains itself rather than apologising.
struct RecapCollageView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    /// The recap this was opened from. A month period pins the screen to that month; a
    /// year or all-time period lets it page across whichever months have photos.
    var period: RecapPeriod = .allTime

    /// The sentence `RecapView` would have shared on its own. Used as the share sheet's
    /// title, so the image arrives with the numbers that produced it.
    var summary: String = ""

    /// Months with at least one photo, oldest first. Resolved on appear.
    @State private var months: [String] = []
    @State private var index = 0
    @State private var pins: [CollagePin] = []
    @State private var backdrop: UIImage?
    @State private var zoomed: CollagePin?
    @State private var shareable: Image?

    /// The photo area of one polaroid. Thumbnails are decoded to exactly this, so the
    /// wall costs a few hundred KB rather than a couple of MB per picture.
    private static let photoSide: CGFloat = 52

    private var month: String { months.indices.contains(index) ? months[index] : "" }
    private var title: RecapPeriod { .month(of: month + "-01") }

    var body: some View {
        ZStack {
            backdropLayer

            VStack(spacing: Tokens.Spacing.lg) {
                header

                Spacer(minLength: 0)

                if pins.isEmpty {
                    emptyState
                } else {
                    card
                }

                Spacer(minLength: 0)

                if months.count > 1 { pager }
            }
            .padding(.horizontal, Tokens.Spacing.xl)
            .padding(.vertical, Tokens.Spacing.xxl)
        }
        // Two tasks, and the split matters: the first resolves *which* months exist, the
        // second reacts to whichever one is showing. Hanging the load off the pager
        // instead would never fire for an account with a single month, because the
        // pager is not built at all when there is nothing to page between.
        .task { resolveMonths() }
        .task(id: month) { await loadMonth() }
        .sheet(item: $zoomed) { pin in
            CollagePhotoDetail(pin: pin, userId: app.evidenceAccountId, monthTitle: title.title)
        }
    }

    // MARK: - Layers

    /// One of the account's own photos, blurred back until it is only a colour wash.
    ///
    /// Blurred rather than shown: the source is a 960×540 video frame, and anything
    /// less than a heavy blur at full-screen size looks like a mistake.
    /// A `Rectangle` carrying the photo as an **overlay**, not a `ZStack` holding both.
    ///
    /// `scaledToFill` reports the filled size as the image's own, and a `ZStack` sizes
    /// itself to its largest child — so a sibling backdrop silently proposes that width
    /// to everything next to it and the calendar ends up twice the width of the screen.
    /// An overlay is measured against its host instead, and `clipped()` takes the rest.
    private var backdropLayer: some View {
        Rectangle()
            .fill(Tokens.Semantic.text)
            .overlay {
                if let backdrop {
                    Image(uiImage: backdrop)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 28)
                }
            }
            .overlay(Color.black.opacity(0.45))
            .clipped()
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            NavigateButton(background: Tokens.Semantic.buttonTintDefault,
                           buttonAction: .close) { dismiss() }
            Spacer()
            if let shareable {
                ShareLink(item: shareable,
                          preview: SharePreview(summary.isEmpty ? title.title : summary,
                                                image: shareable)) {
                    NavigateBadge(background: Tokens.Semantic.buttonTintDefault,
                                  buttonAction: .share)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share your \(title.title) photo wall")
            }
        }
    }

    private var card: some View {
        MonthCollageCard(month: month,
                         monthName: title.shortTitle,
                         year: String(month.prefix(4)),
                         pins: pins,
                         photoSide: Self.photoSide,
                         onTap: { zoomed = $0 })
            // A seven-column grid stretched across an iPad puts the photos so far apart
            // that they stop reading as a pile.
            .frame(maxWidth: 420)
    }

    private var pager: some View {
        HStack(spacing: Tokens.Spacing.xl) {
            pagerButton(.back, enabled: index > 0) { index -= 1 }
            Text(title.title)
                .textStyle(Tokens.Typography.body)
                .foregroundStyle(Tokens.Palette.white)
                .frame(minWidth: 140)
            pagerButton(.forward, enabled: index < months.count - 1) { index += 1 }
        }
    }

    private func pagerButton(_ action: ButtonAction,
                             enabled: Bool,
                             then step: @escaping () -> Void) -> some View {
        Button {
            // Rebuilt from scratch rather than animated across: the wall is a different
            // set of photos, and cross-fading two of them reads as one sliding apart.
            withAnimation(.snappy(duration: 0.2)) { step() }
        } label: {
            Image(systemName: action.action)
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Palette.white)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.25)
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Spacing.md) {
            Image(HabitCategory.actions.iconDetail)
                .resizable()
                .scaledToFit()
                .frame(width: 120)
            Text("No photos this month")
                .textStyle(Tokens.Typography.title)
                .foregroundStyle(Tokens.Palette.white)
            Text("Log an action through the camera and the picture is kept here, on this phone. Photos taken on another device stay there.")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Palette.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Spacing.xxl)
        }
        .padding(.vertical, Tokens.Spacing.goodLord)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.sheet / 2, style: .continuous)
                .fill(Tokens.Palette.white.opacity(0.10))
        )
    }

    // MARK: - Loading

    private func resolveMonths() {
        guard months.isEmpty else { return }
        months = availableMonths()
        // Open on the newest month rather than the oldest — the recap behind this is
        // about what you have been doing lately.
        index = max(0, months.count - 1)
    }

    /// Months with photos, oldest first. Falls back to the month the recap is about, so
    /// an account with nothing photographed still lands somewhere that makes sense.
    private func availableMonths() -> [String] {
        let found = Set(app.photographedLogs(in: period).map { Day.month(of: $0.localDate) })
        if !found.isEmpty { return found.sorted() }

        guard let prefix = period.datePrefix else { return [Day.month(of: Day.today())] }
        if prefix.count >= 7 { return [String(prefix.prefix(7))] }
        // A year with nothing in it: this year lands on today's month, any other on
        // its January, which at least names the year the reader asked for.
        let today = Day.today()
        return [today.hasPrefix(prefix) ? Day.month(of: today) : "\(prefix)-01"]
    }

    /// Metadata first so the calendar can draw, then the pictures as they decode.
    ///
    /// Assigning `pins` per photo rather than once at the end is deliberate — the wall
    /// fills in, which is the honest thing to show while ImageIO works through them.
    private func loadMonth() async {
        shareable = nil
        backdrop = nil
        guard !month.isEmpty else { return }

        var built = app.photographedLogs(in: .month(of: month + "-01"))
            .compactMap { log -> CollagePin? in
                guard let habit = MockData.habitsById[log.habitId],
                      let day = Int(log.localDate.suffix(2)) else { return nil }
                return CollagePin(id: log.remoteId,
                                  day: day,
                                  title: habit.name,
                                  category: habit.category)
            }
        pins = built
        guard !built.isEmpty else { return }

        let account = app.evidenceAccountId
        let maxPixel = Int(Self.photoSide * displayScale)

        for position in built.indices {
            guard !Task.isCancelled else { return }
            built[position].image = await EvidenceStore.loadThumbnail(
                forLogId: built[position].id, userId: account, maxPixel: maxPixel)
            pins = built
        }

        // The newest photo of the month becomes the wash behind the card. Bigger than a
        // polaroid because it covers the screen, still nowhere near the full frame.
        if let newest = built.last?.id {
            backdrop = await EvidenceStore.loadThumbnail(
                forLogId: newest, userId: account, maxPixel: Int(320 * displayScale))
        }

        // Rendered once, off the back of the images already in hand. Doing it inside
        // `ShareLink` instead would re-render the whole wall on every body pass.
        shareable = render()
    }

    /// The card as a flat image, so what gets shared is what is on screen.
    ///
    /// `MonthCollageCard` takes plain values and no `EnvironmentObject` precisely so it
    /// can be handed to `ImageRenderer`, which builds its own hierarchy and would not
    /// inherit one.
    @MainActor private func render() -> Image? {
        let renderer = ImageRenderer(content:
            MonthCollageCard(month: month,
                             monthName: title.shortTitle,
                             year: String(month.prefix(4)),
                             pins: pins,
                             photoSide: Self.photoSide,
                             onTap: nil)
                .frame(width: 360)
                .padding(Tokens.Spacing.xl)
                .background(Tokens.Semantic.text)
        )
        renderer.scale = displayScale
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

// MARK: - One photo on the wall

/// A log that kept a photo, ready to be pinned to a day.
struct CollagePin: Identifiable, Equatable {
    /// The log's `remoteId` — `{habitId}_{localDate}`, and the photo's filename.
    let id: String
    let day: Int
    let title: String
    let category: HabitCategory
    var image: UIImage?
}

// MARK: - The card

/// The month grid with the photos over it.
///
/// Deliberately free of `AppState`: everything it draws arrives as a value, which is
/// what lets `ImageRenderer` produce the shared image from the same code the screen
/// uses rather than a second layout that can drift from it.
private struct MonthCollageCard: View {
    let month: String
    let monthName: String
    let year: String
    let pins: [CollagePin]
    let photoSide: CGFloat

    /// `nil` when rendering to an image, where nothing can be tapped anyway.
    let onTap: ((CollagePin) -> Void)?

    private let rowHeight: CGFloat = 46

    private var layout: MonthLayout? { MonthLayout(month: month) }

    /// One blob per category logged this month, in a fixed order so the same month
    /// draws the same way twice.
    private var categories: [HabitCategory] {
        HabitCategory.allCases.filter { category in pins.contains { $0.category == category } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            heading
            if let layout {
                weekdays(layout)
                grid(layout)
            }
        }
        .padding(Tokens.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.sheet / 2, style: .continuous)
                .fill(Tokens.Palette.white)
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
        )
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
            Text(year)
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
            Text(monthName)
                .textStyle(Tokens.Typography.hero)
                .foregroundStyle(Tokens.Semantic.text)
        }
    }

    private func weekdays(_ layout: MonthLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(layout.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func grid(_ layout: MonthLayout) -> some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / 7

            ZStack(alignment: .topLeading) {
                rules(layout)
                blobs(width: proxy.size.width, layout: layout)
                numbers(layout, cell: cell)
                photos(layout, cell: cell)
            }
        }
        .frame(height: CGFloat(layout.rowCount) * rowHeight)
    }

    /// Faint week rules, so the thing still reads as a calendar under the pile.
    private func rules(_ layout: MonthLayout) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<layout.rowCount, id: \.self) { _ in
                Rectangle()
                    .fill(Tokens.Semantic.footnote.opacity(0.18))
                    .frame(height: 1)
                    .frame(height: rowHeight, alignment: .top)
            }
        }
    }

    /// The mascots, scattered behind the photos. Positions are seeded by the category
    /// so a month does not rearrange itself between launches.
    private func blobs(width: CGFloat, layout: MonthLayout) -> some View {
        let height = CGFloat(layout.rowCount) * rowHeight
        return ForEach(categories) { category in
            let seed = StableHash.of(category.rawValue + month)
            Image(category.iconDetail)
                .resizable()
                .scaledToFit()
                .frame(width: 96 * category.iconScale)
                // Inset from the edges: a blob centred at the margin is a blob sliced
                // in half by the card, which reads as a rendering fault rather than
                // as decoration.
                .position(x: width * (0.22 + 0.56 * StableHash.unit(seed)),
                          y: height * (0.22 + 0.56 * StableHash.unit(seed >> 21)))
                .opacity(0.9)
        }
    }

    private func numbers(_ layout: MonthLayout, cell: CGFloat) -> some View {
        ForEach(1...layout.dayCount, id: \.self) { day in
            Text("\(day)")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.text)
                .position(centre(of: day, layout: layout, cell: cell))
        }
    }

    private func photos(_ layout: MonthLayout, cell: CGFloat) -> some View {
        ForEach(pins) { pin in
            let seed = StableHash.of(pin.id)
            Polaroid(pin: pin, side: photoSide)
                .rotationEffect(.degrees(StableHash.spread(seed, by: 13)))
                .position(centre(of: pin.day, layout: layout, cell: cell))
                .offset(x: StableHash.spread(seed >> 17, by: 9),
                        y: StableHash.spread(seed >> 34, by: 7))
                .onTapGesture { onTap?(pin) }
                .accessibilityLabel("\(pin.title), day \(pin.day)")
        }
    }

    private func centre(of day: Int, layout: MonthLayout, cell: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(layout.column(of: day)) * cell + cell / 2,
                y: CGFloat(layout.row(of: day)) * rowHeight + rowHeight / 2)
    }
}

/// One picture, in the frame the shape is named after.
///
/// The caption carries the day rather than being the blank band a real polaroid has:
/// photos overlap on purpose here, and once a pile covers the grid the date underneath
/// it is gone. Reading the day off the photo itself is what keeps the wall legible.
private struct Polaroid: View {
    let pin: CollagePin
    let side: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // The category tint stands in until the photo decodes, so the wall
                // arrives laid out rather than assembling itself hole by hole.
                Rectangle().fill(pin.category.tint)
                if let image = pin.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: side, height: side)
            .clipped()

            Text("\(pin.day)")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)
                .frame(width: side, height: 16)
        }
        .padding(4)
        .background(Tokens.Palette.white)
        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Tapping one

/// The full-size photo, and which log it belongs to.
private struct CollagePhotoDetail: View {
    let pin: CollagePin
    let userId: String
    let monthTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: Tokens.Spacing.lg) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.basicCards,
                                                    style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: Tokens.Radius.basicCards, style: .continuous)
                        .fill(pin.category.tint)
                        .aspectRatio(9 / 16, contentMode: .fit)
                }

                VStack(spacing: Tokens.Spacing.xxs) {
                    Text(pin.title)
                        .textStyle(Tokens.Typography.title)
                        .foregroundStyle(Tokens.Semantic.text)
                    Text("\(pin.day) \(monthTitle)")
                        .textStyle(Tokens.Typography.footnote)
                        .foregroundStyle(Tokens.Semantic.footnote)
                }

                Spacer(minLength: 0)
            }
            .padding(Tokens.Spacing.xl)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle(pin.category.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        // Full size here, and only here: it is one picture filling the screen, which is
        // the one place the thumbnail would actually look soft.
        .task {
            image = await Task.detached(priority: .userInitiated) {
                EvidenceStore.image(forLogId: pin.id, userId: userId)
            }.value
        }
    }
}

// MARK: - Calendar geometry

/// Where each day of a `YYYY-MM` sits in a seven-column grid.
///
/// The weekday columns follow the reader's locale — `Calendar.current.firstWeekday` is
/// Monday in most of Europe and Sunday in the US, and a grid whose header says one and
/// whose columns mean the other is worse than either.
///
/// The month's own arithmetic stays in UTC, matching `Day`: `localDate` is a plain
/// string written at log time, and re-deriving it through a local calendar is how the
/// first of the month becomes the last of the one before.
nonisolated struct MonthLayout {
    let firstColumn: Int
    let dayCount: Int
    let rowCount: Int
    let weekdaySymbols: [String]

    init?(month: String) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!

        guard let first = Day.date(from: month + "-01"),
              let range = utc.range(of: .day, in: .month, for: first) else { return nil }

        let firstWeekday = Calendar.current.firstWeekday
        firstColumn = (utc.component(.weekday, from: first) - firstWeekday + 7) % 7
        dayCount = range.count
        rowCount = Int((Double(firstColumn + range.count) / 7).rounded(.up))

        let formatter = DateFormatter()
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        weekdaySymbols = (0..<7).map { symbols[($0 + firstWeekday - 1) % symbols.count] }
    }

    func column(of day: Int) -> Int { (firstColumn + day - 1) % 7 }
    func row(of day: Int) -> Int { (firstColumn + day - 1) / 7 }
}

/// Scatter that survives a relaunch.
///
/// **Not `String.hashValue`.** Swift seeds that per process, so the entire wall would
/// re-arrange itself every time the app is opened — the photos would be the same, and
/// the picture the user remembers would not be.
nonisolated enum StableHash {

    /// FNV-1a.
    static func of(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }

    /// `0...1`.
    static func unit(_ seed: UInt64) -> Double { Double(seed % 1000) / 1000 }

    /// `-limit...limit`.
    static func spread(_ seed: UInt64, by limit: Double) -> Double {
        (unit(seed) * 2 - 1) * limit
    }
}

#if DEBUG
#Preview("Collage") {
    RecapCollageView(period: .allTime)
        .environmentObject(AppState.preview)
}
#endif
