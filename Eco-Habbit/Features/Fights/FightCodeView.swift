import SwiftUI
import CoreImage.CIFilterBuiltins

/// The organiser's check-in code, shown at the venue for attendees to scan or type.
///
/// **Direction matters.** The alternative was each attendee showing a personal QR
/// for the host to scan — one code per person. That is a cross-user write: the
/// host's device has to credit somebody else's account, which needs a server to
/// authorise. One code for the whole Fight inverts it, so each attendee's own
/// device credits its own account, and the app needs no special permission at all.
///
/// The trade is honest: a shared code can be photographed and passed to somebody
/// who never turned up. With no leaderboard and no prizes that costs nothing, and
/// the check-in window already bounds it to the day of the event.
struct FightCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let fight: Fight

    /// Restored on dismiss — nobody wants their screen left at full brightness.
    @State private var previousBrightness = UIScreen.main.brightness

    /// Hidden until asked for. The QR is the fast path and should own the screen; the
    /// characters are the fallback for a camera that will not focus, someone across a
    /// room, or a phone with no camera permission.
    @State private var showingCode = false

    var body: some View {
        NavigationStack {
            // Just the code. The title, location, typed fallback and window guidance
            // that used to sit around it were all things the organiser already knows —
            // and this screen is held up across a table, where anything but the code is
            // something for a camera to miss.
            VStack(spacing: Tokens.Spacing.lg) {
                Spacer()
                qrCard
                // Which event this code belongs to. An organiser running two on one
                // day is holding up two identical squares otherwise.
                Text(fight.title)
                    .textStyle(Tokens.Typography.title2)
                    .foregroundStyle(Tokens.Semantic.text)
                    .multilineTextAlignment(.center)

                if showingCode {
                    typedCode
                } else {
                    Button("Show code") {
                        withAnimation(.snappy(duration: 0.2)) { showingCode = true }
                    }
                    .textStyle(Tokens.Typography.body)
                    .foregroundStyle(Tokens.Semantic.footnote)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Tokens.Spacing.lg)
            .background(Tokens.Palette.white.ignoresSafeArea())
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .textStyle(Tokens.Typography.body)
                }
            }
        }
        .onAppear {
            previousBrightness = UIScreen.main.brightness
            // A dim screen is unscannable across a table in daylight. This is a
            // scanning-reliability measure, not polish.
            UIScreen.main.brightness = 1.0
        }
        .onDisappear { UIScreen.main.brightness = previousBrightness }
    }

    // MARK: - Sections


    private var qrCard: some View {
        Group {
            // The QR carries the scheme; the text below carries the bare code.
            // Scanning and typing are different jobs — a camera pointed at the
            // world needs to know this belongs to the app, a person typing six
            // characters does not.
            if let image = Self.qr(from: fight.checkInPayload) {
                Image(uiImage: image)
                    .interpolation(.none)      // keep the modules crisp when scaled
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Could not render code")
                    .textStyle(Tokens.Typography.footnote)
                    .foregroundStyle(Tokens.Semantic.footnote)
            }
        }
        .frame(width: 240, height: 240)
        .padding(Tokens.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Tokens.Semantic.statIcon.opacity(0.3), lineWidth: 1)
        )
    }



    /// The same code as characters, for reading aloud or typing.
    ///
    /// Monospaced and tracked out: this gets read across a table and dictated, and the
    /// alphabet already excludes `0/O` and `1/I` for the same reason.
    private var typedCode: some View {
        VStack(spacing: Tokens.Spacing.xs) {
            Text("OR TYPE")
                .textStyle(Tokens.Typography.footnote)
                .foregroundStyle(Tokens.Semantic.footnote)

            Text(fight.checkInCode)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .tracking(6)
                .foregroundStyle(Tokens.Semantic.text)
                .textSelection(.enabled)
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.vertical, Tokens.Spacing.sm)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Tokens.Semantic.buttonTintDefault))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: - Rendering

    /// CoreImage emits the symbol at its natural size — one pixel per module,
    /// about 25 across. Scaling it up here, rather than letting SwiftUI
    /// interpolate, is what keeps it scannable from across a table.
    ///
    /// `correctionLevel "M"` is the trade: higher correction means more modules,
    /// so a denser code at the same physical size. This lives on a bright screen
    /// for one afternoon and needs to be read at distance, not to survive being
    /// scuffed — so fewer, larger modules win.
    static func qr(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)      // the filter takes bytes, not a String
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
