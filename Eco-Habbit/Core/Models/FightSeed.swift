import Foundation

/// `fights.json` stores each event as an **offset from launch**, not an absolute date.
///
/// Absolute dates in seed data go stale: a week after they are written the whole list is
/// in the past and the exhibit demo shows an empty screen. Offsets mean the seeded events
/// are always upcoming, and `f1` — offset −1h, 10h long — always has an **open check-in
/// window**, which is exactly what PRD §12.1 asks for.
nonisolated struct FightSeed: Codable {
    let id: String
    let title: String
    let summary: String
    let type: FightType
    let hostName: String
    let hostId: String
    let locationName: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    /// Hours from now. Negative means it has already started.
    let startOffsetHours: Double
    let durationHours: Double
    var preparationNotes: [String] = []
    var isDemo: Bool = true

    func materialise(now: Date = Date()) -> Fight {
        let start = now.addingTimeInterval(startOffsetHours * 3600)
        return Fight(
            id: id,
            title: title,
            summary: summary,
            type: type,
            hostName: hostName,
            hostId: hostId,
            locationName: locationName,
            address: address,
            latitude: latitude,
            longitude: longitude,
            startsAt: start,
            endsAt: start.addingTimeInterval(durationHours * 3600),
            preparationNotes: preparationNotes,
            status: .published,
            isDemo: isDemo
        )
    }
}
