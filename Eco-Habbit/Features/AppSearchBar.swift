//
//  AppSearchBar.swift
//  Eco-Habbit
//
//  Created by Max on 13/08/26.
//

import SwiftUI

struct AppSearchBar: View{
    @Binding var text: String
    var prompt: String = "Search"

    /// Supply this and the leaf becomes a "show only what I have checked off" toggle.
    ///
    /// Optional rather than a plain `@Binding` because the leaf predates any filter and
    /// a future search bar may have nothing to filter. `nil` keeps it decorative, which
    /// is exactly what the standalone preview below wants — and it means adding the
    /// filter did not change any other call site.
    var completedFilter: Binding<Bool>? = nil

    @FocusState private var isFocused: Bool
    @StateObject private var dictation = DictationService()

    var body: some View{
        HStack{
            leaf
            HStack (spacing: Tokens.Spacing.sm){
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Tokens.Semantic.footnote)
                
                TextField(prompt, text: $text)
                    .font(.system (size: 16, weight: .regular))
                    .foregroundStyle(Tokens.Semantic.text)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if dictation.isSupported {
                    Button {
                        isFocused = false
                        dictation.toggle()
                    } label: {
                        Image(systemName: dictation.isRecording ? "microphone.fill" : "microphone")
                            .foregroundStyle(dictation.isRecording
                                             ? Tokens.Palette.orange
                                             : Tokens.Semantic.footnote)
                            // Sized here rather than on the Button so the tap area is the
                            // whole 44pt square, not just the glyph.
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(dictation.isRecording ? "Stop dictating" : "Dictate search")
                }
            }
            .padding(.horizontal, Tokens.Spacing.md)
            // The 44pt mic sets the capsule's height on its own; adding the usual
            // vertical padding on top would make it noticeably taller than before.
            .glassed(in: .capsule, fallback: Tokens.Semantic.buttonTintDefault)
            .onChange(of: dictation.transcript) { _, spoken in
                guard !spoken.isEmpty else { return }
                text = spoken
            }
            .alert(
                "Dictation unavailable",
                isPresented: Binding(
                    get: { dictation.errorMessage != nil },
                    set: { if !$0 { dictation.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(dictation.errorMessage ?? "")
            }
            
            if !text.isEmpty{
                Button {
                    text = ""
                    isFocused = false
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .glassed(in: .circle, fallback: Tokens.Semantic.buttonTintDefault)
            }
        }
    }
}

private extension AppSearchBar {

    /// A toggle when there is something to toggle, the original decoration otherwise.
    @ViewBuilder
    var leaf: some View {
        if let completedFilter {
            Button {
                isFocused = false
                withAnimation(.snappy(duration: 0.2)) {
                    completedFilter.wrappedValue.toggle()
                }
            } label: {
                leafGlyph(active: completedFilter.wrappedValue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(completedFilter.wrappedValue
                                ? "Showing only completed actions"
                                : "Show only completed actions")
            .accessibilityAddTraits(completedFilter.wrappedValue ? .isSelected : [])
        } else {
            leafGlyph(active: false)
        }
    }

    /// Filled and solid when on. The glass treatment is the *resting* look, so leaving
    /// it applied in both states makes an active filter almost impossible to see.
    @ViewBuilder
    func leafGlyph(active: Bool) -> some View {
        let glyph = Image(systemName: "leaf.fill")
            .textStyle(Tokens.Typography.title)
            .foregroundStyle(active ? Tokens.Palette.white : Tokens.Semantic.text)
            .padding(Tokens.Spacing.md)

        if active {
            glyph
                .background(Circle().fill(Tokens.Palette.greenDark))
                .contentShape(Circle())
        } else {
            glyph
                .glassed(in: .circle, fallback: Tokens.Semantic.buttonTintDefault)
                .contentShape(Circle())
        }
    }
}

extension View {
    @ViewBuilder
    func glassed(in shape: some Shape, fallback: Color) -> some View {
        if #available(iOS 26.0, *){
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self .background(shape.fill(.ultraThinMaterial))
                .background(shape.fill(fallback.opacity(0.5)))
                .overlay(shape.stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }
}

#Preview {
    struct Harness: View {
        @State private var text = ""
        var body: some View {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<12, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Tokens.Palette.white)
                            .frame(height: 80)
                    }
                }
                .padding()
            }
            .background(Tokens.Palette.orangeCard)
            .safeAreaInset(edge: .bottom) {
                AppSearchBar(text: $text)
                    .padding(.horizontal, Tokens.Spacing.md)
                    .padding(.bottom, Tokens.Spacing.sm)
            }
        }
    }
    return Harness()
}
