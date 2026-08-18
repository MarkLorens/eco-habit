import Foundation

/// Date and countdown strings for Fights.
///
/// Four screens format the same dates — the card, the detail sheet, the
/// check-in code screen and the organiser's manage view. It used to sit at the
/// bottom of `FightListView`, which meant a shared helper was only findable by
/// already knowing where to look.
enum FightFormat {
    static func when(_ fight: Fight) -> String {
        let day = fight.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let from = fight.startsAt.formatted(date: .omitted, time: .shortened)
        let to = fight.endsAt.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(from)–\(to)"
    }

    static func countdown(_ fight: Fight, from now: Date = Date()) -> String {
        let seconds = fight.startsAt.timeIntervalSince(now)
        if seconds < 0 { return "Happening now" }
        let hours = Int(seconds / 3600)
        if hours < 1 { return "Starts in \(max(1, Int(seconds / 60))) min" }
        if hours < 24 { return "Starts in \(hours)h" }
        return "In \(hours / 24) day\(hours / 24 == 1 ? "" : "s")"
    }
    
    static func shortWhen(_ fight: Fight) -> String {
        let day = fight.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let time = fight.startsAt.formatted(date: .omitted, time: .shortened)
        return "\(day) • \(time)"
    }
}
