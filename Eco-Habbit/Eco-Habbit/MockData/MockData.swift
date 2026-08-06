import Foundation

/// Everything that would come from a backend one day. Pure static data — no I/O.
nonisolated enum MockData {

    // MARK: - Activity catalog

    static let activities: [Activity] = [
        // Waste reduction
        Activity(id: "w1", name: "Bring a reusable bag", category: .waste,
                 basePoints: 10, isCameraDetectable: true, effort: .medium),
        Activity(id: "w2", name: "Bring your own container", category: .waste,
                 basePoints: 10, isCameraDetectable: true, effort: .medium),
        Activity(id: "w3", name: "Refill instead of rebuy", category: .waste,
                 basePoints: 15, isCameraDetectable: true, effort: .medium),
        Activity(id: "w4", name: "Sort your waste for recycling", category: .waste,
                 basePoints: 8, isCameraDetectable: true, effort: .light),
        Activity(id: "w5", name: "Finish your plate — zero food waste", category: .waste,
                 basePoints: 8, isCameraDetectable: false, effort: .light),
        Activity(id: "w6", name: "Skip single-use packaging", category: .waste,
                 basePoints: 10, isCameraDetectable: false, effort: .medium),

        // Energy saving
        Activity(id: "e1", name: "Unplug idle electronics", category: .energy,
                 basePoints: 6, isCameraDetectable: false, effort: .light),
        Activity(id: "e2", name: "Air-dry instead of the dryer", category: .energy,
                 basePoints: 10, isCameraDetectable: true, effort: .medium),
        Activity(id: "e3", name: "Switch off lights you're not using", category: .energy,
                 basePoints: 5, isCameraDetectable: false, effort: .light),
        Activity(id: "e4", name: "Set the AC to 25°C or higher", category: .energy,
                 basePoints: 12, isCameraDetectable: true, effort: .medium),
        Activity(id: "e5", name: "Run a full load, not a half one", category: .energy,
                 basePoints: 10, isCameraDetectable: false, effort: .medium),

        // Water conservation
        Activity(id: "a1", name: "Take a shower under 5 minutes", category: .water,
                 basePoints: 10, isCameraDetectable: false, effort: .medium),
        Activity(id: "a2", name: "Turn off the tap while brushing", category: .water,
                 basePoints: 5, isCameraDetectable: false, effort: .light),
        Activity(id: "a3", name: "Collect rinse water for plants", category: .water,
                 basePoints: 12, isCameraDetectable: true, effort: .medium),
        Activity(id: "a4", name: "Fix or report a dripping tap", category: .water,
                 basePoints: 15, isCameraDetectable: true, effort: .medium),
        Activity(id: "a5", name: "Water plants before sunrise", category: .water,
                 basePoints: 8, isCameraDetectable: true, effort: .light),

        // Green mobility
        Activity(id: "m1", name: "Walk, bike, or take transit", category: .mobility,
                 basePoints: 15, isCameraDetectable: true, effort: .medium),
        Activity(id: "m2", name: "Carpool to your destination", category: .mobility,
                 basePoints: 12, isCameraDetectable: true, effort: .medium),
        Activity(id: "m3", name: "Work from home today", category: .mobility,
                 basePoints: 10, isCameraDetectable: false, effort: .medium),
        Activity(id: "m4", name: "Combine errands into one trip", category: .mobility,
                 basePoints: 8, isCameraDetectable: false, effort: .light),

        // Community action
        Activity(id: "c1", name: "Join a local clean-up", category: .community,
                 basePoints: 20, isCameraDetectable: true, effort: .medium),
        Activity(id: "c2", name: "Share a tip with a neighbour", category: .community,
                 basePoints: 8, isCameraDetectable: false, effort: .light),
        Activity(id: "c3", name: "Donate or swap something reusable", category: .community,
                 basePoints: 12, isCameraDetectable: true, effort: .medium),
        Activity(id: "c4", name: "Bring a friend into a green habit", category: .community,
                 basePoints: 10, isCameraDetectable: false, effort: .medium),
    ]

    static let activitiesById: [String: Activity] = Dictionary(
        uniqueKeysWithValues: activities.map { ($0.id, $0) }
    )

    static func activities(in category: ActivityCategory) -> [Activity] {
        activities.filter { $0.category == category }
    }

    /// The subset the mocked detector is allowed to return.
    static let cameraDetectable: [Activity] = activities.filter(\.isCameraDetectable)

    // MARK: - Regional missions

    static let regionalMissions: [RegionalMission] = [
        RegionalMission(
            id: "r1",
            title: "Sanur Beach Clean-Up",
            region: "Bali",
            locationName: "Sanur Beach",
            date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            points: 75,
            kind: .event,
            category: .community
        ),
        RegionalMission(
            id: "r2",
            title: "Refill Friday at Canggu",
            region: "Bali",
            locationName: "Canggu Refill Station",
            date: Date(),
            points: 20,
            kind: .daily,
            category: .waste
        ),
    ]

    // MARK: - Vouchers

    static let vouchers: [Voucher] = [
        Voucher(
            id: "v1", partner: "Green Bowl Beach Club", title: "20% Off Any Meal", points: 400,
            terms: [
                "Valid for one use per member",
                "Cannot be combined with other offers",
                "Expires 30 days after redemption",
            ],
            howToUse: [
                "Redeem below to add it to My Vouchers",
                "Show the voucher code at checkout",
                "The partner confirms and applies your reward",
            ]
        ),
        Voucher(
            id: "v2", partner: "Ubud Eco Lodge", title: "Free Night Upgrade", points: 1_200,
            terms: [
                "Subject to room availability",
                "Minimum two-night stay",
                "Expires 30 days after redemption",
            ],
            howToUse: [
                "Redeem below to add it to My Vouchers",
                "Mention the code when you book",
                "Show it at check-in",
            ]
        ),
        Voucher(
            id: "v3", partner: "Alaya Resort Canggu", title: "Complimentary Spa Hour", points: 900,
            terms: [
                "Booking required 24 hours ahead",
                "One treatment per member",
                "Expires 30 days after redemption",
            ],
            howToUse: [
                "Redeem below to add it to My Vouchers",
                "Call the spa with your code",
                "Show the voucher on arrival",
            ]
        ),
        Voucher(
            id: "v4", partner: "Warung Local Bali", title: "Buy 1 Get 1 Fresh Juice", points: 150,
            terms: [
                "Valid daily until 5pm",
                "Dine-in only",
                "Expires 30 days after redemption",
            ],
            howToUse: [
                "Redeem below to add it to My Vouchers",
                "Show the voucher when ordering",
                "Bring your own cup for an extra 5 pts",
            ]
        ),
        Voucher(
            id: "v5", partner: "Sea Communities Bali", title: "Free Reef Snorkel Tour", points: 1_500,
            terms: [
                "Weather dependent",
                "Ages 12 and up",
                "Expires 30 days after redemption",
            ],
            howToUse: [
                "Redeem below to add it to My Vouchers",
                "Reserve a slot with your code",
                "Show the voucher at the dive shop",
            ]
        ),
    ]

    static let vouchersById: [String: Voucher] = Dictionary(
        uniqueKeysWithValues: vouchers.map { ($0.id, $0) }
    )

    // MARK: - Badges

    static let badges: [Badge] = [
        Badge(id: "b1", name: "First Step", tier: "Milestone",
              detail: "Logged your very first sustainable action.",
              requirement: .totalActions(1)),
        Badge(id: "b2", name: "7-Day Streak", tier: "Streak",
              detail: "Kept your habit alive for a full week.",
              requirement: .streak(7)),
        Badge(id: "b3", name: "30-Day Streak", tier: "Streak",
              detail: "Log an action every day for 30 days straight.",
              requirement: .streak(30)),
        Badge(id: "b4", name: "Proof Keeper", tier: "Milestone",
              detail: "Attached evidence to 5 different actions.",
              requirement: .evidenceCount(5)),
        Badge(id: "b5", name: "Earth Day Hero", tier: "Seasonal",
              detail: "Available every April 22 — Earth Day.",
              requirement: .seasonal),
        Badge(id: "b6", name: "Century Club", tier: "Milestone",
              detail: "Log 100 total actions.",
              requirement: .totalActions(100)),
        Badge(id: "b7", name: "Community Champion", tier: "Regional",
              detail: "Log 3 community actions.",
              requirement: .categoryActions(.community, 3)),
        Badge(id: "b8", name: "Reef Guardian", tier: "Rare",
              detail: "Reach the Thriving stage — 3,500 Earth Points.",
              requirement: .earthPoints(3_500)),
    ]

    // MARK: - Demo account

    /// Pre-filled so the login screen isn't a wall of empty fields during review.
    static let demoEmail = "made@ecohabit.app"
    static let demoPassword = "planet2026"
    static let demoName = "Made Wirawan"
}
