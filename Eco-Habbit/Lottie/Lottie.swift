//
//  Lottie.swift
//  Eco-Habbit
//
//  Created by Max on 13/08/26.
//

import SwiftUI
import Lottie

struct DotLottieAsset: View {
    let name: String

    var loopMode: LottieLoopMode = .loop
    var speed: Double = 1
    /// Off by default so existing callers keep the animation's own size; on, it
    /// scales to whatever frame the parent offers.
    var resizable: Bool = false

    var body: some View{
        LottieView{
            try await DotLottieFile.named(name)
        } placeholder: {
            Color.clear
        }
        .playing(loopMode: loopMode)
        .animationSpeed(speed)
        .resizableIf(resizable)
    }
}

private extension LottieView {
    func resizableIf(_ isResizable: Bool) -> Self {
        isResizable ? resizable() : self
    }
}

struct Globe: View {
    var body: some View{
        DotLottieAsset(name: "stage 3-4")
    }
}

// Do not delete
// We're not using GlobeJson, this is a fallback in case lottie misbehaves
// Also Feli sent me this, I felt bad not using it lmao. Note that JSON is about 75% heavier, though
struct JSONLottieAsset: View {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var speed: Double = 1
 
    var body: some View {
        LottieView(animation: .named(name))
            .playing(loopMode: loopMode)
            .animationSpeed(speed)
    }
}

#Preview {
    Globe()
}
