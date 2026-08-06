import SwiftUI

struct RedeemView: View {
    @EnvironmentObject private var app: AppState

    @State private var tab: Tab = .available
    @State private var detailVoucher: Voucher?

    private enum Tab: Hashable { case available, mine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Points & Rewards")
                    .font(Theme.F.heading(24))
                    .foregroundStyle(Theme.C.text)

                balances

                EHSegmented(
                    options: [(.available, "Available"), (.mine, "My Vouchers")],
                    selection: $tab
                )
                .padding(.top, 20)

                switch tab {
                case .available: availableList
                case .mine: myVouchers
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .tabContentInsets()
        }
        .background(Theme.C.bg)
        .sheet(item: $detailVoucher) { voucher in
            VoucherDetailSheet(voucher: voucher)
                .presentationDetents([.large])
        }
    }

    // MARK: Balances

    private var balances: some View {
        HStack(spacing: 10) {
            BalanceCard(
                kicker: "Earth Points",
                kickerTint: Theme.C.accent2_700,
                value: app.earthPoints,
                caption: "Powers your Earth's recovery. Not spendable."
            )
            BalanceCard(
                kicker: "Reward Points",
                kickerTint: Theme.C.accent700,
                value: app.rewardPoints,
                caption: "Spend on real-world rewards. Never expires."
            )
        }
        .padding(.top, 16)
    }

    // MARK: Lists

    private var availableList: some View {
        VStack(spacing: 12) {
            ForEach(MockData.vouchers) { voucher in
                VoucherCard(
                    voucher: voucher,
                    affordable: app.canAfford(voucher),
                    owned: app.hasRedeemed(voucher)
                ) {
                    detailVoucher = voucher
                }
            }
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private var myVouchers: some View {
        if app.redeemedVouchers.isEmpty {
            EHCard(padding: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing redeemed yet")
                        .font(Theme.F.body(15, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                    Text("Reward Points don't expire — spend them whenever you're ready.")
                        .font(Theme.F.body(13.5))
                        .foregroundStyle(Theme.C.neutral700)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 16)
        } else {
            VStack(spacing: 12) {
                ForEach(app.redeemedVouchers) { record in
                    if let voucher = MockData.vouchersById[record.voucherId] {
                        RedeemedCard(voucher: voucher, record: record)
                    }
                }
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Cards

private struct BalanceCard: View {
    let kicker: String
    let kickerTint: Color
    let value: Int
    let caption: String

    var body: some View {
        EHCard(padding: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kicker.uppercased())
                    .font(Theme.F.body(11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(kickerTint)

                Text(value.formatted(.number.grouping(.automatic)))
                    .font(Theme.F.heading(24))
                    .foregroundStyle(Theme.C.text)
                    .contentTransition(.numericText())

                Text(caption)
                    .font(Theme.F.body(11.5))
                    .foregroundStyle(Theme.C.neutral600)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct VoucherCard: View {
    let voucher: Voucher
    let affordable: Bool
    let owned: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                VoucherArtwork(seed: voucher.id)
                    .frame(height: 90)
                    .washed()

                VStack(alignment: .leading, spacing: 2) {
                    Text(voucher.partner)
                        .font(Theme.F.body(12))
                        .foregroundStyle(Theme.C.neutral600)

                    Text(voucher.title)
                        .font(Theme.F.body(15, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                        .multilineTextAlignment(.leading)

                    HStack {
                        EHTag(text: "\(voucher.points) pts", style: .outline)
                        if owned {
                            EHTag(text: "Redeemed", style: .accent2)
                        } else if !affordable {
                            Text("Not enough points yet")
                                .font(Theme.F.body(11.5))
                                .foregroundStyle(Theme.C.neutral600)
                        }
                        Spacer()
                        Text(owned ? "View" : "Redeem")
                            .font(Theme.F.heading(13))
                            .foregroundStyle(Theme.C.text)
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(Capsule().stroke(Theme.C.divider, lineWidth: 1))
                    }
                    .padding(.top, 10)
                }
                .padding(14)
            }
            .background(RoundedRectangle(cornerRadius: Theme.R.card).fill(Theme.C.surface))
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.card))
            .elevation(Theme.E.sm)
        }
        .buttonStyle(PlainPressStyle())
    }
}

private struct RedeemedCard: View {
    let voucher: Voucher
    let record: RedeemedVoucher

    var body: some View {
        EHCard(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.C.accent2_700)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.C.accent2_100))

                VStack(alignment: .leading, spacing: 2) {
                    Text(voucher.title)
                        .font(Theme.F.body(14.5, weight: .bold))
                        .foregroundStyle(Theme.C.text)
                    Text("\(voucher.partner) · Show at checkout")
                        .font(Theme.F.body(12))
                        .foregroundStyle(Theme.C.neutral600)
                }

                Spacer()

                Text(record.code)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.C.accent700)
            }
        }
    }
}

/// Stand-in for partner photography — a deterministic warm gradient per voucher.
struct VoucherArtwork: View {
    let seed: String

    var body: some View {
        let hash = abs(seed.hashValue)
        let pair = Self.pairs[hash % Self.pairs.count]
        LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 90, height: 90)
                    .offset(x: 26, y: 30)
            }
            .clipped()
    }

    /// Deeper ramp steps than the design's flat swatch: `.washed()` knocks roughly a
    /// third of the saturation out, and 100/200 steps disappear into the ground.
    private static let pairs: [[Color]] = [
        [Theme.C.accent2_400, Theme.C.accent300],
        [Theme.C.accent400, Theme.C.accent2_300],
        [Theme.C.accent2_500, Theme.C.neutral300],
        [Theme.C.accent300, Theme.C.accent2_400],
        [Theme.C.neutral400, Theme.C.accent2_400],
    ]
}
