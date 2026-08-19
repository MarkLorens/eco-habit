//
//  GlobeStageUpOverlay.swift
//  Eco-Habbit
//

import SwiftUI

extension View {
    /// The new-stage celebration: `modalCard`'s dim, without the card. The transition
    /// Lottie loops over the dimmed app until the user taps it away.
    func globeStageUpOverlay(item: Binding<GlobeStageUp?>) -> some View {
        modifier(GlobeStageUpModifier(stageUp: item))
    }
}

private struct GlobeStageUpModifier: ViewModifier {

    @Binding var stageUp: GlobeStageUp?

    /// The dim swallows taps from the first frame — this only gates *dismissal*, so a
    /// tap aimed at the button underneath can't skip an animation the user never saw.
    @State private var isDismissible = false

    private static let touchLock: Duration = .seconds(1)

    func body(content: Content) -> some View {
        content
            .overlay {
                if let stageUp {
                    ZStack {
                        Color.black.opacity(0.55)
                            .ignoresSafeArea()

                        DotLottieAsset(name: stageUp.lottieName, resizable: true)
                            .containerRelativeFrame(.horizontal) { width, _ in
                                min(width * 0.9, 420)
                            }
                            .aspectRatio(1, contentMode: .fit)
                            .allowsHitTesting(false)

                        if isDismissible {
                            Text("Tap to continue")
                                .textStyle(Tokens.Typography.body)
                                .foregroundStyle(Tokens.Palette.white.opacity(0.85))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, Tokens.Spacing.goodLord)
                                .transition(.opacity)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Your Earth reached stage \(stageUp.to)")
                    .accessibilityHint("Tap to continue")
                    .task(id: stageUp.id) {
                        isDismissible = false
                        try? await Task.sleep(for: Self.touchLock)
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 0.25)) { isDismissible = true }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: stageUp)
    }

    private func dismiss() {
        guard isDismissible else { return }
        stageUp = nil
    }
}

#if DEBUG
#Preview {
    GlobeView(stage: 3)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .globeStageUpOverlay(item: .constant(GlobeStageUp(from: 3, to: 4)))
}
#endif
