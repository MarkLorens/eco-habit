import SwiftUI

struct VoucherDetailSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let voucher: Voucher

    @State private var justRedeemed: RedeemedVoucher?
    @State private var shortfall: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    CircleIconButton(systemName: "xmark", size: 30) { dismiss() }
                }

                VoucherArtwork(seed: voucher.id)
                    .frame(height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .washed()
                    .padding(.top, 6)

                Text(voucher.partner)
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)
                    .padding(.top, 14)

                Text(voucher.title)
                    .font(Theme.F.heading(20))
                    .foregroundStyle(Theme.C.text)
                    .padding(.top, 2)

                HStack(spacing: 8) {
                    EHTag(text: "\(voucher.points) pts", style: .outline, fontSize: 12)
                    Text("Reward Points only — your Earth Points stay untouched.")
                        .font(Theme.F.body(11.5))
                        .foregroundStyle(Theme.C.neutral600)
                }
                .padding(.top, 8)

                if let record = justRedeemed ?? existingRecord {
                    successBlock(record)
                } else {
                    termsBlock
                }
            }
            .padding(20)
        }
        .background(Theme.C.bg)
    }

    private var existingRecord: RedeemedVoucher? {
        app.redeemedVouchers.first { $0.voucherId == voucher.id }
    }

    private func successBlock(_ record: RedeemedVoucher) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.C.accent2_700)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.C.accent2_100))
                .padding(.top, 12)

            Text("Added to My Vouchers")
                .font(Theme.F.body(15, weight: .bold))
                .foregroundStyle(Theme.C.text)

            Text(record.code)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.C.accent700)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.C.accent100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(Theme.C.accent300)
                        )
                )

            Text("Redeemed \(record.redeemedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(Theme.F.body(12))
                .foregroundStyle(Theme.C.neutral600)

            Button("Done") { dismiss() }
                .buttonStyle(SecondaryButtonStyle(height: 44))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var termsBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Terms")
                .font(Theme.F.body(14, weight: .bold))
                .foregroundStyle(Theme.C.text)
                .padding(.top, 20)

            ForEach(voucher.terms, id: \.self) { term in
                Text("· \(term)")
                    .font(Theme.F.body(13.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .padding(.top, 4)
            }

            Text("How to use")
                .font(Theme.F.body(14, weight: .bold))
                .foregroundStyle(Theme.C.text)
                .padding(.top, 16)

            ForEach(Array(voucher.howToUse.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)")
                    .font(Theme.F.body(13.5))
                    .foregroundStyle(Theme.C.neutral700)
                    .padding(.top, 4)
            }

            if let shortfall {
                Text("You need \(shortfall) more Reward Points for this one.")
                    .font(Theme.F.body(13, weight: .semibold))
                    .foregroundStyle(Theme.C.accent700)
                    .padding(.top, 16)
            }

            Button("Redeem for \(voucher.points) pts", action: redeem)
                .buttonStyle(PrimaryButtonStyle(height: 50))
                .disabled(!app.canAfford(voucher))
                .padding(.top, 18)

            if !app.canAfford(voucher) {
                Text("You have \(app.rewardPoints) Reward Points.")
                    .font(Theme.F.body(12))
                    .foregroundStyle(Theme.C.neutral600)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
    }

    private func redeem() {
        switch app.redeem(voucher) {
        case .success(let record):
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                justRedeemed = record
                shortfall = nil
            }
            app.toast = Toast(kind: .success, message: "Redeemed · \(voucher.title)")
        case .insufficientPoints(let short):
            withAnimation { shortfall = short }
        }
    }
}
