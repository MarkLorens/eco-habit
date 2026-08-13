import SwiftUI
import CoreImage.CIFilterBuiltins

/// The organiser's check-in code, shown at the venue for attendees to scan or copy.
///
/// **Direction matters.** This used to be the attendee showing a personal QR for
/// the host to scan — one code per person. That is a cross-user write: the host's
/// device has to credit somebody else's account, which needs a server to
/// authorise. One code for the whole Fight inverts it, so each attendee's own
/// device credits its own account, and the app needs no special permission at all.
///
/// The trade is honest: a shared code can be photographed and passed to someone
/// who never turned up. For a v1 with no leaderboard and no prizes, that costs
/// nothing — and the check-in window already bounds it to the day of the event.
struct FightCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let fight: Fight

    /// Restored on dismiss — nobody wants their screen left at full brightness.
    @State private var previousBrightness = UIScreen.main.brightness

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.S.x4) {
                    header
                    qrCard
                    typedCode
                    guidance
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.S.x4)
                .padding(.vertical, Theme.S.x4)
            }
            .background(Theme.C.bg.ignoresSafeArea())
            .navigationTitle("Check-in code")
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
            // A dim screen is unscannable across a table in daylight.
            UIScreen.main.brightness = 1.0
        }
        .onDisappear { UIScreen.main.brightness = previousBrightness }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Theme.S.x1) {
            Text(fight.title)
                .font(Theme.F.heading(20))
                .foregroundStyle(Theme.C.text)
                .multilineTextAlignment(.center)
            Text(FightFormat.when(fight))
                .font(Theme.F.body(13.5))
                .foregroundStyle(Theme.C.neutral600)
        }
    }

    private var qrCard: some View {
        Group {
            if let image = Self.qr(from: fight.checkInCode) {
                Image(uiImage: image)
                    .interpolation(.none)      // keep the modules crisp when scaled up
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Could not render code")
                    .font(Theme.F.body(13))
                    .foregroundStyle(Theme.C.neutral600)
            }
        }
        .frame(width: 240, height: 240)
        .padding(Theme.S.x4)
        .background(RoundedRectangle(cornerRadius: Theme.R.lg).fill(.white))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.R.lg)
                .stroke(Theme.C.divider, lineWidth: 1)
        )
    }

    /// The same code in text, because half the room will type it rather than
    /// queue to point a camera at a phone.
    private var typedCode: some View {
        VStack(spacing: Theme.S.x1) {
            Text("or type")
                .font(Theme.F.body(11.5, weight: .semibold))
                .foregroundStyle(Theme.C.neutral600)
                .textCase(.uppercase)

            Text(fight.checkInCode)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .tracking(6)
                .foregroundStyle(Theme.C.text)
                .textSelection(.enabled)
                .padding(.horizontal, Theme.S.x4)
                .padding(.vertical, Theme.S.x2)
                .background(
                    RoundedRectangle(cornerRadius: Theme.R.md)
                        .fill(Theme.C.surface)
                )
        }
    }

    private var guidance: some View {
        VStack(spacing: 6) {
            if fight.isCheckInOpen() {
                Label("Check-in is open", systemImage: "checkmark.circle.fill")
                    .font(Theme.F.body(14, weight: .bold))
                    .foregroundStyle(Theme.C.accent2_700)
            } else {
                Label("Opens an hour before the start", systemImage: "clock")
                    .font(Theme.F.body(14, weight: .semibold))
                    .foregroundStyle(Theme.C.neutral600)
            }

            Text("Show this to everyone who turns up. They scan or type it in their own app.")
                .font(Theme.F.body(12.5))
                .foregroundStyle(Theme.C.neutral600)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// CoreImage renders the QR at its natural module size — a few dozen points
    /// across. Scaling it up here, rather than letting SwiftUI interpolate, is
    /// what keeps it scannable from across a table.
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
