import SwiftUI
import CoreImage.CIFilterBuiltins

/// PRD §6.5 — full-screen check-in QR, brightness boosted.
///
/// The host scans the attendee, not the other way round (§4.5): the host controls the
/// physical space, so a code displayed by the host could be photographed and shared with
/// people who never showed up. Reversing the direction means the credential lives on the
/// attendee's phone.
struct CheckInQRView: View {
    @Environment(\.dismiss) private var dismiss
    let fight: Fight
    let signup: FightSignup

    /// Restored on dismiss — nobody wants their screen left at full brightness.
    @State private var previousBrightness = UIScreen.main.brightness

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.S.x4) {
                Spacer()

                VStack(spacing: Theme.S.x2) {
                    Text(fight.title)
                        .font(Theme.F.heading(20))
                        .foregroundStyle(Theme.C.text)
                        .multilineTextAlignment(.center)
                    Text(FightFormat.when(fight))
                        .font(Theme.F.body(13.5))
                        .foregroundStyle(Theme.C.neutral600)
                }

                qrImage
                    .frame(width: 240, height: 240)
                    .padding(Theme.S.x4)
                    .background(RoundedRectangle(cornerRadius: Theme.R.lg).fill(.white))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.R.lg)
                            .stroke(Theme.C.divider, lineWidth: 1)
                    )

                VStack(spacing: 4) {
                    if fight.isCheckInOpen() {
                        Label("Check-in is open", systemImage: "checkmark.circle.fill")
                            .font(Theme.F.body(14, weight: .bold))
                            .foregroundStyle(Theme.C.accent2_700)
                    } else {
                        Label("Opens an hour before the start", systemImage: "clock")
                            .font(Theme.F.body(14, weight: .semibold))
                            .foregroundStyle(Theme.C.neutral600)
                    }
                    Text("Show this to the host at the venue.")
                        .font(Theme.F.body(12.5))
                        .foregroundStyle(Theme.C.neutral600)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.S.x4)
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.F.body(15, weight: .semibold))
                }
            }
        }
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
        .onDisappear { UIScreen.main.brightness = previousBrightness }
    }

    private var qrImage: some View {
        Group {
            if let image = Self.qr(from: signup.checkInToken) {
                Image(uiImage: image)
                    .interpolation(.none)     // keep the modules crisp when scaled up
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Could not render code")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
            }
        }
    }

    /// CoreImage renders the QR at its natural module size — a few dozen points across.
    /// Scaling it up here, rather than letting SwiftUI interpolate, is what keeps it
    /// scannable from across a table.
    static func qr(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
