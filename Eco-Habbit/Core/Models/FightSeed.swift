import Foundation

/// One entry in `fights.json`.
///
/// Dates are absolute ISO 8601, matching what the partner admin app writes.
/// The previous format stored offsets from launch so seeded demo events never
/// went stale — that trick is gone now that real partners supply real dates,
/// so **the seed file has to be refreshed when its dates pass** or the list
/// shows nothing.
struct FightSeed: Codable {
    let id: String
    let title: String
    let summary: String
    /// One of the six the rest of the app uses, not a Fight-only taxonomy.
    let category: Category
    let hostName: String
    let hostId: String
    let locationName: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let startsAt: Date
    let endsAt: Date

    /// Asset name for the partner's photo. Omit while there is none.
    var imageName: String?

    /// Fixed in the seed file, not generated.
    ///
    /// `Fight.checkInCode` defaults to a fresh random code, which is right for a
    /// Fight a real organiser creates — but a generated code would change on
    /// every launch, and any printed card or poster at the booth would stop
    /// working.
    let checkInCode: String

    /// Optional: `f7` has none, so "points only" has a demo case too.
    var rewardBadgeId: String?

    var preparationNotes: [String] = []
    var isDemo: Bool = true

    func materialise() -> Fight {
        Fight(
            id: id,
            title: title,
            summary: summary,
            category: category,
            hostName: hostName,
            hostId: hostId,
            locationName: locationName,
            address: address,
            latitude: latitude,
            longitude: longitude,
            startsAt: startsAt,
            endsAt: endsAt,
            preparationNotes: preparationNotes,
            imageName: imageName,
            status: .published,
            isDemo: isDemo,
            checkInCode: checkInCode,
            rewardBadgeId: rewardBadgeId
        )
    }
}
